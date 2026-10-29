|   SIP-Number | |
|         ---: | :--- |
|        Title | Forwarding Addresses |
|  Description | Keyless addresses that route balance deposits to a registered master address while recording which address was paid. |
|       Author | Xun Li \<xun@mystenlabs.com, @lxfind\> |
|       Editor | |
|         Type | Standard |
|     Category | Core, Framework |
|      Created | 2026-10-09 |
| Comments-URI | |
|       Status | |
|     Requires | 58 |

## Abstract

A forwarding address is a 32-byte Sui address that carries no key. Its bytes encode a master id assigned by an on-chain registry, a fixed magic marker, a format variant and 16 payload bytes chosen by the issuer. When funds are sent to it, Sui delivers them to the registered master address and emits an event that records the forwarding address they came through. The forwarding address itself never holds anything. Both address-balance deposits and coin objects are forwarded; any other object sent to a forwarding address fails the transaction. Registration costs a flat gas fee, and each master id has a pause switch and a time-delayed master rotation so that a leaked key is survivable.

## Motivation

A payment app, exchange or merchant wants to hand out a distinct deposit address per customer or invoice, so it can tell who paid without asking the payer to attach a memo. It does not want to hold one key per address, and it does not want to sweep funds from thousands of addresses into one account.

On Sui today the options are a key per address with periodic sweeps, or a custom Move contract that wraps every deposit. Both put work on the recipient that the chain could do once for everyone. Forwarding addresses give an issuer an unbounded supply of deposit addresses that all pay a single account, with a tag distinguishing each user or payment preserved in an event. Any wallet or protocol that can send a `Balance<T>` or transfer a coin object to an address can pay a forwarding address with no changes.

### Example

1. A merchant registers once and receives a master id. Its account address becomes the master.
2. For each invoice, the merchant's backend derives a forwarding address from the master id and a 16-byte invoice number, and shows it to the customer. Deriving an address is a local computation; nothing is written on chain.
3. The customer pays from any wallet, by sending USDC to that address as an address balance or as a coin.
4. The USDC lands in the merchant's address balance. A `ForwardingDeposit<USDC>` event names the forwarding address and the amount, so the merchant's app reads the invoice number from it and marks the invoice paid. The app can verify the event with a light client instead of trusting a fullnode.

### Chains

The master of a master id can itself be a forwarding address. Funds then pass through two or more forwarding addresses before reaching an account, and each one records the deposit. This serves businesses whose funds are held by someone else:

- **A merchant using a custodian or payment processor.** The custodian has its own master id and gives each client merchant a forwarding address under it, with the merchant's account number as the payload. The merchant registers its own master id with that forwarding address as its master, and issues invoice addresses under its own id. A customer pays an invoice address; the funds reach the custodian's account; the custodian sees which merchant was paid, and the merchant sees which invoice was paid. The merchant keeps its own invoice numbering and its own `MasterCap`, and the custodian never has to learn the merchant's invoice scheme.
- **Changing custodians.** The merchant rotates its master id from one custodian's forwarding address to another's. Every invoice and customer address it has already handed out keeps working and now pays the new custodian.
- **Sub-accounts.** An exchange or wallet provider can give each institutional client a master id whose master is a forwarding address of the provider's own id, so per-client and per-customer attribution both survive while all funds land in one account.

Chains are limited to 3 hops.

## Specification

### Address format

All integers are little-endian.

```
[u48 master_id][0xfa x 9][u8 variant][16 payload bytes]
 0..6           6..15     15          16..32
```

The magic is nine `0xfa` bytes at offset 6. An address with the magic at that offset is a forwarding address; an address without it is ordinary. There is no other signal, so a wallet or contract can tell a forwarding address from its bytes alone; `sui::forwarding_address::is_forwarding_address(addr)` does the same check in Move.

The master id is 48 bits, assigned by the registry at registration. Move and Rust carry it as a `u64`.

The variant decides what the payload bytes mean. Variant 0 is the only one defined and gives the payload no on-chain meaning: under variant 0 the issuer chooses the 16 bytes freely, typically an invoice or customer id. Later variants can give them structure, such as a coin-type allow list, a minimum amount or an expiry. Sending to an address whose variant is not yet supported fails the transaction instead of being treated as an ordinary recipient, so nobody can fund an address whose meaning a later version will define.

### Registering a master

```move
public fun register(registry: &mut ForwardingAddressRegistry, rotation_delay_epochs: u64, ctx: &mut TxContext): MasterCap;
public fun register_with_forwarding_master(registry: &mut ForwardingAddressRegistry, master: address, rotation_delay_epochs: u64, ctx: &mut TxContext): MasterCap;
public fun master_id(cap: &MasterCap): u64;
```

`register` records the transaction sender as the master of a new master id, emits `MasterRegistered { master_id, master, cap_id, rotation_delay_epochs }` and returns a `MasterCap` that controls the id (see [Managing a master](#managing-a-master)). `rotation_delay_epochs`, between 1 and 30, is how long a change of master must wait.

`register_with_forwarding_master` creates an id whose master is a forwarding address, which builds a [chain](#chains). The sender cannot be a forwarding address, so `register` cannot do this. `master` must be a forwarding address with a supported variant, and its master id must not be the id being created; otherwise registration aborts. It does not have to be registered yet, and its id may belong to someone else. There is no way to register an ordinary address other than the sender as a master: an ordinary master must agree to be one, and it agrees by sending the transaction.

Master ids are assigned by the registry, not chosen. They look random, but they are not secret or unguessable: anyone can predict the next one. They are mixed only so that ids are not handed out as 1, 2, 3 and so on, which would give early registrants recognisable low numbers and invite people to race for memorable ones.

Registration charges a flat fee of 1,000,000 gas units, about 1 SUI at a gas price of 1,000 MIST, on top of normal gas and storage. The fee is paid as gas, so it goes to validators like any other gas. A registration is permanent: master ids are never reused and records are never deleted.

Anyone can look up who a forwarding address pays. The registry is the shared object at `0xfa`, and each master id has a dynamic field holding its `MasterRecord`: the current master, whether the id is paused, and any pending rotation.

### Sending to a forwarding address

Paying a forwarding address looks the same as paying any other address. The payer does not need to know about the registry or declare it as an input to the transaction; Sui reads it on the payer's behalf.

What happens depends on what is sent and on the state of the master id:

| Recipient                            | Balance deposit                                   | `Coin<T>` object                                                         | Any other object  |
| ------------------------------------ | ------------------------------------------------- | ------------------------------------------------------------------------ | ----------------- |
| Ordinary address (no magic)          | Credited as today                                 | Transferred as today                                                     | Transferred as today |
| Forwarding address, id registered and not paused | Credited to the master, `ForwardingDeposit` event | Coin melted, its value credited to the master, `ForwardingDeposit` event | Transaction fails |
| Forwarding address, id unregistered  | Transaction fails                                 | Transaction fails                                                        | Transaction fails |
| Forwarding address, id paused        | Transaction fails                                 | Transaction fails                                                        | Transaction fails |
| Forwarding address, unsupported variant | Transaction fails                              | Transaction fails                                                        | Transaction fails |

A coin sent to a forwarding address and a `Balance<T>` sent to it are indistinguishable to the master: both arrive as an address-balance credit with the same event. Nothing other than funds can be forwarded.

- **Coins are melted.** A `Coin<T>` sent to a forwarding address, by `TransferObjects`, `transfer::public_transfer` or any other transfer, is destroyed and its value is credited to the master's address balance, exactly as if the payer had turned it into a `Balance<T>` and sent that. The master never receives coin objects through a forwarding address.
- **Other objects fail.** Any other object sent to a forwarding address fails the whole transaction, including objects that wrap or hold coins and party objects that would give a forwarding address permissions. Nobody can sign for a forwarding address, so an object left there would be lost.
- **The gas coin cannot be sent.** Sending the gas coin itself to a forwarding address, with `coin::send_funds` or `TransferObjects`, fails the transaction. The amount the master would receive depends on the gas the transaction ends up using, so no event could state what was paid. Split the amount off the gas coin and send that instead.
- **Register first, then pay.** A deposit is resolved against the registry as it was before the transaction began. Registering a master id and paying one of its forwarding addresses in the same transaction fails, and the registration is rolled back with it. A registration, pause or rotation does apply to every transaction ordered after it, including later transactions in the same checkpoint.
- **Chains.** If a master is itself a forwarding address, the funds are forwarded again, up to 3 hops. A longer chain, a cycle, or any id along the chain being unregistered or paused fails the transaction.

Forwarding costs a small amount of extra gas for each forwarding address a transaction pays, including each hop of a chain, to cover reading the registry and emitting the event. The payer is charged even if the id turns out to be unregistered.

Forwarding works with gasless payments. A payment that qualifies as a gasless transaction stays gasless when the recipient is a forwarding address: the forwarding work fits within the gasless computation limit, and the payer pays nothing for it. The gasless rule that a payer's remaining balance must be zero or at least the per-token minimum is about the payer, not the recipient, so forwarding does not change it.

When a transaction fails because of a forwarding address, the whole transaction fails and nothing is credited, as with any execution failure. The payer keeps their funds and can retry. On devnet these failures currently appear as the generic `FeatureNotYetSupported` status; dedicated error statuses will be added before testnet.

Move unit tests that use `test_scenario` see the same forwarding behavior when a simulated transaction ends.

### Receiving payments

```move
public struct ForwardingDeposit<phantom T> has copy, drop { forwarding_address: address, master: address, amount: u64 }
```

Each transaction emits one `ForwardingDeposit<T>` per forwarding address and coin type it paid, with `amount` the total sent to that address in the transaction, whether as balances, as coins, or both. A payment therefore produces one event no matter how the payer built the transaction.

In a chain, each hop gets its own event, naming the forwarding address paid at that hop and the master it forwarded to. A payment to merchant invoice address `A`, whose master is the custodian's forwarding address `F`, whose master is the custodian's account `C`, emits `A → F` and then `F → C`. The events of one transaction, read in order, give the path the funds took.

Forwarding events count toward the per-transaction limits on the number and total size of events, like events emitted from Move. A transaction that pays more forwarding addresses than the limits allow fails.

The event carries the whole forwarding address, so the variant and payload survive losslessly. A reader takes bytes 16..32 as the payload; variant 0 gives them no structure to parse.

A payment app has to match every deposit to an invoice and should not have to trust a fullnode about which events happened. Every `ForwardingDeposit<T>` is therefore also recorded in an authenticated event stream keyed by the event's `master`: one stream per master address, listing every deposit forwarded to it across all of its forwarding addresses. In a chain, each hop's event goes to the stream of that hop's master, so in the example above `A → F` is in `F`'s stream and `F → C` is in `C`'s. Reading a stream needs no key, so the owner of a forwarding address that other ids forward to reads that forwarding address's stream to see who paid into it. A light client can read the stream and verify each event against a commitment in the checkpoints, with no trust in the node that served it. This uses the authenticated event streams Sui already has; the only difference is that the stream is keyed by the master address rather than by a Move package, and only Sui itself can write to it.

A payment app subscribes with the Rust light client, `AuthenticatedEventsClient::stream_events(master)`, and for each verified `ForwardingDeposit<T>` reads the coin type from `T`, the amount, and the invoice or customer id from the payload. It needs no indexer and no per-address subscription; a new forwarding address shows up in the master's stream the first time it is paid. Apps that already trust their node can keep using ordinary event queries (gRPC `ListEvents` or GraphQL), and an indexer can key a table by forwarding address.

The registry also emits ordinary Move events for lifecycle changes: `MasterRegistered { master_id, master, cap_id, rotation_delay_epochs }`, `Paused { master_id }`, `Unpaused { master_id }`, `RotationProposed { master_id, new_master, effective_epoch }`, `RotationCancelled { master_id }`, `RotationFinalized { master_id, master }` and `RotationDelayIncreased { master_id, rotation_delay_epochs }`.

### Managing a master

Two keys control an id. The master receives the funds and is expected to be hot. The `MasterCap` is expected to be cold and is the only key that can redirect funds or resume deposits.

```move
public fun pause(registry: &mut ForwardingAddressRegistry, cap: &MasterCap);
public fun pause_by_master(registry: &mut ForwardingAddressRegistry, master_id: u64, ctx: &TxContext);
public fun unpause(registry: &mut ForwardingAddressRegistry, cap: &MasterCap);

public fun propose_rotation(registry: &mut ForwardingAddressRegistry, cap: &MasterCap, new_master: address, ctx: &TxContext);
public fun cancel_rotation(registry: &mut ForwardingAddressRegistry, cap: &MasterCap);
public fun cancel_rotation_by_master(registry: &mut ForwardingAddressRegistry, master_id: u64, ctx: &TxContext);
public fun finalize_rotation(registry: &mut ForwardingAddressRegistry, master_id: u64, ctx: &TxContext);
public fun increase_rotation_delay(registry: &mut ForwardingAddressRegistry, cap: &MasterCap, rotation_delay_epochs: u64);
```

Pause is immediate and either key can do it: the cap through `pause`, the current master through `pause_by_master`. While paused, deposits to the id, including coins, fail like deposits to an unregistered id. Pausing an already paused id does nothing. Only the cap can `unpause`.

Rotation is two-step. The cap proposes `new_master`, which can be an ordinary address or a forwarding address that `register_with_forwarding_master` would accept. The change can take effect `rotation_delay_epochs` epochs later; before that, finalizing aborts. If `new_master` is an ordinary address, `finalize_rotation` must be sent by `new_master`, which is how it agrees to become the master. If it is a forwarding address, anyone may finalize. Deposits keep crediting the old master while a rotation is pending. Either the cap or the current master can cancel a pending rotation, and a new proposal replaces a pending one. A proposal whose new master never finalizes stays pending until it is cancelled or replaced.

An id whose master is a forwarding address can only be managed with the cap. Nobody can sign as a forwarding address, so `pause_by_master` and `cancel_rotation_by_master` cannot be called for such an id. If the cap is stolen, no second key can stop the thief's rotation. Owners of such ids should keep the cap especially safe and choose a long rotation delay.

The rotation delay is chosen at registration and can later only be increased, through `increase_rotation_delay`. An id can be paused and have a rotation pending at the same time.

### Interaction with other features

Deny lists for regulated coins apply to the master, not to the forwarding address. Denying a master blocks deposits through all of its forwarding addresses; denying a forwarding address has no effect.

Funds withdrawn from an object's balance and sent to a forwarding address are forwarded like any other deposit.

Transaction simulation and dry run forward deposits the same way execution does, so a wallet can show the result before the payer signs.

### Rollout

Forwarding addresses are live on devnet. On testnet and mainnet they ship in two steps: one release creates the registry, and a later release turns on forwarding. Until forwarding is on, an address with the magic is an ordinary address.

An emergency brake, a protocol flag under which every payment to a forwarding address fails while registration and management keep working, exists and is off everywhere. It is separate from the feature switch because switching the feature off would turn forwarding addresses back into ordinary addresses, and funds sent to them would be stranded.

## Rationale

The address has to be recognisable without a lookup, so that a wallet can warn before sending and execution can decide what to resolve. Nine magic bytes plus the variant byte give ten bytes that must line up for an address to be treated as a forwarding address, a collision probability of 2^-72 per key-derived address. 48 bits of id give 2^48 registrants and leave 16 bytes of payload for future variants that need structure.

Forwarding is built into the protocol rather than offered as a Move contract, so that `balance::send_funds`, `TransferObjects` and every existing payment path work with forwarding addresses unchanged, and payers need no new API.

Coins are melted rather than transferred to the master so that a payment arrives in one form however it was sent. A payment app reconciling invoices sees an address-balance credit and one `ForwardingDeposit<T>` per forwarding address and coin type, whether the payer used `send_funds`, `TransferObjects` on a coin, or a mix, and does not have to track coin objects at all. Other objects fail because they are not payments: there is no amount to record, and an arbitrary object at the master would have no record of which forwarding address it came through.

Payers do not declare the registry, because a payer should not have to know that an address is a forwarding address, let alone which object resolves it.

Ids are assigned by the registry, so there is no name to race for and no front-running. They are mixed so that no one gains from registering early; nothing relies on them being secret.

Pause is immediate and either key can do it because pausing only stops deposits and never moves money, so a delay would only help an attacker, and letting the hot key pause means the brake can be hit without fetching the cap. Unpause is cap-only because if the master key could unpause, a stolen master key would undo the owner's pause and keep draining during the rotation delay. A stolen cap can keep an id paused, but a stolen cap already controls rotation; the remedy is a new id.

Rotation is two-step so that redirecting funds takes the cap plus the delay, while pausing or cancelling takes either key. A thief needs both keys to win, and the owner needs one to stop them. Anyone may finalize so the cap can go back in the safe after proposing.

The delay can only increase because a decrease would need its own timelock to stay safe against a stolen cap. A registrant who wants a shorter delay registers a new id.

The registration fee is paid as gas and goes to validators, so there is no treasury or distribution question. Records are permanent, so the fee also prices the permanent storage growth.

Deposits go into the master's authenticated event stream, rather than only into plain events, because the party that must act on a deposit (ship goods, credit an account) is exactly the party that should not have to trust a fullnode, and the master address is the one key under which all of its forwarding addresses naturally group. Keying the stream by master also means a payment app opens one subscription, not one per invoice.

Chains exist so that a business can receive funds into an account it does not hold, such as a custodian's, while keeping its own deposit addresses, its own payload scheme and its own control of where funds go. Without chains, the custodian would have to issue and track every invoice address on the business's behalf, and the business could not change custodians without reissuing every address it had given out. With a chain, the custodian sees one forwarding address per client and the client sees one per invoice, and rotating the client's id moves all of its addresses to a new custodian at once.

Each hop gets its own event, keyed into the stream of that hop's master, because each forwarding address in a chain usually belongs to a different party, and each party needs to see deposits into its own address. In the custodian example, the custodian reads `F`'s stream to see which merchant was paid and `C`'s stream to see totals per merchant, and does not receive events about the merchant's invoice addresses in `C`'s stream. A single event keyed by the final master would put every upstream party's events in the custodian's stream and give the intermediate parties no stream at all.

An ordinary address only becomes a master by sending a transaction: the sender of `register`, or the sender of `finalize_rotation`. Otherwise anyone could register an id with a well-known merchant or exchange as its master and hand out its addresses. Payments through them would reach the merchant, but whoever holds the cap could later rotate the id to themselves, while payers, wallets and indexers would see an id that appears to belong to the merchant. A forwarding address cannot sign, so it cannot agree to anything; pointing an id at it only sends that id's own deposits there, which is no different from paying the forwarding address directly. That is why a forwarding-address master needs no consent.

Anything that would land at a forwarding address without resolution (an unregistered id, an unsupported variant, an over-long chain) fails the transaction, because nobody can sign for the address and funds left there would be lost. The payer keeps their funds and can retry.

## Backwards Compatibility

There is no change to Sui's on-wire types. `ForwardingDeposit` is an ordinary Move event, a melted coin appears in effects as a deleted object plus an address-balance deposit, and the registry read appears in effects as a read-only shared object, all shapes that SDKs and indexers already handle.

Before forwarding was enabled, an address carrying the magic was an ordinary address. Any funds already held at such an address stay where they are and remain spendable by whoever holds the key; only deposits and coins sent after forwarding turns on are forwarded, and other objects sent to such an address after that fail. For a key-derived address the chance of carrying the magic is 2^-72, so with 2^32 addresses in existence the chance that any of them is affected is about 2^-40.

The dedicated error statuses for forwarding failures are an on-wire change. They will be added to the Rust SDK types and the gRPC API before any network produces them.

## Reference Implementation

- Registry as an implicitly read system object: https://github.com/MystenLabs/sui/pull/27989 (merged).
- Address format, registration, forwarding of balance deposits, `ForwardingDeposit` event, pause and two-step rotation: https://github.com/MystenLabs/sui/pull/28236.
- Forwarded deposits recorded in the master's authenticated event stream: https://github.com/MystenLabs/sui/pull/28261.
- Coin melting, chains of forwarding addresses, `register_with_forwarding_master`, rotation to a forwarding address, and per-hop events in each hop master's stream: https://github.com/MystenLabs/sui/pull/28246 (draft, stacked on #28261).
- Requiring the new master to send `finalize_rotation`: https://github.com/MystenLabs/sui/pull/28236.
- Forwarding events counted toward the per-event and total event size limits, and the emergency brake flag: https://github.com/MystenLabs/sui/pull/28236.

Implementation details that do not affect how the feature is used, such as how and when execution resolves forwarding addresses, the gas charged for each step, how master ids are derived, how the registry version is pinned per transaction, how deposits are recorded in the master's stream, and the protocol configuration and rollout order, are described in the [design doc](https://github.com/MystenLabs/sui/blob/xun/forwarding-address-resolution/crates/sui-framework/design_docs/forwarding_addresses.md) (`crates/sui-framework/design_docs/forwarding_addresses.md`, added in #28236).

## Security Considerations

Signature security is unchanged. A forwarding address is never a signer, and ordinary addresses keep the same key derivation. Owning a key whose address happens to carry the magic buys nothing, since everything sent to that address goes to the master.

A key-derived address collides with the magic with probability 2^-72. Grinding a key whose address carries the magic costs about 2^72 hashes, and grinding one for a specific master id costs 2^120. Because control of a forwarding address is worthless, these numbers only matter for accidental collisions.

Unregistered ids, paused ids, unsupported variants, cycles and over-long chains fail the transaction, and no object or funds can be left at a forwarding address. Switching the feature off would strand funds, which is why the emergency brake is a separate switch.

Registration costs about 1 SUI plus permanent storage, and the id space is 2^48. Forwarding charges gas for every registry read, including reads of unregistered ids, and for every event it emits, so neither can be spammed for free.

Every validator resolves a forwarding address against the same registry state, fixed before the transaction executes, so resolution is deterministic and reproduced exactly on replay.

Only Sui itself writes to a master's event stream, and only with deposits it forwarded, so no third party can inject an entry into another master's stream. A light client that verifies a `ForwardingDeposit` against the stream gets the same guarantee it gets for any authenticated event.

Two keys control an id, and the lifecycle is built so that losing either one is survivable. A leaked master key is contained by pausing (immediate, either key) and rotating (cap, delayed): pause, propose, wait, finalize, unpause. A leaked cap is caught because its rotation waits out the delay, during which the master cancels it. Losing both is not survivable, and nothing is designed for it. An id whose master is a forwarding address has only the cap, so for such ids losing the cap is not survivable either.

An id in a chain depends on every id after it. If the owner of a downstream id pauses it, rotates it, or makes its chain longer than 3 hops, deposits to the upstream id fail. This cannot be used against someone else's id: only an id's cap holder decides what it points at, and a broken chain only fails deposits to ids whose owners chose to point into it. Anyone can point their own id at someone else's forwarding address, which credits that address's master as if it had been paid directly; issuers should therefore match deposits on the full forwarding address, not on the payload alone.

## Open Questions

- Rotation delay bounds are `1..=30` epochs. Are they right?
- Should a registrant be able to shorten the delay behind its own timelock, or is increase-only enough?
- Registration price: 1,000,000 gas units (about 1 SUI at a 1,000 MIST gas price) is the starting point. It should hurt for spam and not for a legitimate business.
- Brake semantics: should the emergency brake fail every deposit to a forwarding address, or only skip resolution and strand? The current proposal is to fail.
- Format: 48-bit id, 9-byte magic, 16-byte payload, collision margin 2^-72 per address. Revisit only before the format leaves devnet.
- Chains are bounded at 3 hops. Is that enough for custodian and sub-account setups, without letting a registrant make payers pay for long chains?
- Should an id whose master is a forwarding address get a second key for pause and cancel, for example letting the end of the chain pause it, so that a stolen cap is survivable for chained ids too?
- Can an object address (a shared or owned object's id) be a master, given nobody can sign for it and its balance is only reachable through object funds withdrawals?
- Do issuers of regulated coins need to deny a single forwarding address, or is denying the master enough?
- Should `MasterRecord` be readable from other Move packages (a `master_of(registry, id)` view), or is off-chain lookup enough for now?

## Copyright

Copyright (c) Mysten Labs, Inc.
