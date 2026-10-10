|   SIP-Number | |
|         ---: | :--- |
|        Title | Forwarding Addresses |
|  Description | Keyless addresses that route balance deposits and object transfers to a registered master address while recording which address was paid. |
|       Author | Xun Li \<lxfind@gmail.com, @lxfind\> |
|       Editor | |
|         Type | Standard |
|     Category | Core, Framework |
|      Created | 2026-10-09 |
| Comments-URI | |
|       Status | |
|     Requires | 58 |

## Abstract

A forwarding address is a 32-byte Sui address that carries no key. Its bytes encode a master id assigned by an on-chain registry, a fixed magic marker, a format variant and 16 payload bytes chosen by the issuer. When funds or objects are sent to it, execution resolves it through the registry and delivers them to the registered master address, emitting an event that records the forwarding address they came through. The forwarding address itself never holds anything. Resolution runs in the execution layer after Move execution finishes, so it covers address-balance deposits and object transfers alike. Registration costs a flat gas fee, and each master id has a pause switch and a time-delayed master rotation so that a leaked key is survivable.

## Motivation

A payment app, exchange or merchant wants to hand out a distinct deposit address per customer or invoice, so it can tell who paid without asking the payer to attach a memo. It does not want to hold one key per address, and it does not want to sweep funds from thousands of addresses into one account.

On Sui today the options are a key per address with periodic sweeps, or a custom Move contract that wraps every deposit. Both put work on the recipient that the chain could do once for everyone. Forwarding addresses give an issuer an unbounded supply of deposit addresses that all pay a single account, with the invoice tag preserved in an event. Any wallet or protocol that can send a `Balance<T>` or transfer an object to an address can pay a forwarding address with no changes.

## Specification

### Address format

All integers are little-endian.

```
[u48 master_id][0xfa x 9][u8 variant][16 payload bytes]
 0..6           6..15     15          16..32
```

The magic is nine `0xfa` bytes at offset 6. An address with the magic at that offset is a forwarding address; an address without it is ordinary. There is no other signal.

The master id is 48 bits, assigned by the registry at registration. Id 0 is reserved and never allocated. Move and Rust carry it as a `u64`.

The variant decides what the payload bytes mean. Variant 0 is the only one defined and gives the payload no on-chain meaning: the resolver never reads it, so an invoice tag only has to be distinct. The protocol config `forwarding_address_max_variant` (0 at protocol version 139) is the highest variant the resolver accepts. A deposit to an address with a higher variant fails the transaction instead of being treated as an ordinary recipient, so nobody can fund an address whose meaning a later version will define.

The payload is 16 bytes whose meaning the variant defines. Under variant 0 the issuer chooses them freely, typically an invoice or customer id. Later variants can give them structure, such as a coin-type allow list, a minimum amount or an expiry.

How execution treats a recipient address:

| Recipient                              | Balance deposit                                   | Object transfer                                 |
| -------------------------------------- | ------------------------------------------------- | ----------------------------------------------- |
| No magic                               | Credited as today                                 | As today                                        |
| Magic, variant <= max, id registered   | Credited to the master, `ForwardingDeposit` event | Owned by the master, `ForwardingTransfer` event |
| Magic, variant <= max, id unregistered | Transaction fails                                 | Transaction fails                               |
| Magic, variant <= max, id paused       | Transaction fails                                 | Transaction fails                               |
| Magic, variant > max                   | Transaction fails                                 | Transaction fails                               |

A master that is itself a forwarding address resolves again, up to `forwarding_address_max_hops` hops (3 at 139). A longer chain fails the transaction.

### Registry

`sui::forwarding_address::ForwardingAddressRegistry` is a shared system object at address `0xfa`, created by an end-of-epoch transaction when the protocol flag `create_forwarding_address_registry` turns on. Its struct is `{ id: UID }` and all state hangs off the `UID` as dynamic fields:

- `master_id: u64 -> MasterRecord { master: address, paused: bool, pending: Option<PendingRotation>, rotation_delay_epochs: u64 }`
- `MasterIdCounter {} -> u64`, the next counter value, starting at 1

`PendingRotation` is `{ new_master: address, effective_epoch: u64 }`.

The registry is an implicitly read system object. Consensus assigns every transaction a registry version, execution reads master records at that version, and the read appears in effects as a read-only consensus object. A transaction does not declare the registry as an input to deposit to a forwarding address; it declares it only to call the lifecycle functions below, which take it as a mutable shared input.

### Registration

```move
public fun register(registry: &mut ForwardingAddressRegistry, rotation_delay_epochs: u64, ctx: &mut TxContext): MasterCap;
public fun master_id(cap: &MasterCap): u64;
```

`register` allocates a master id, stores `MasterRecord { master: ctx.sender(), paused: false, pending: none, rotation_delay_epochs }`, emits `MasterRegistered { master_id, master, cap_id, rotation_delay_epochs }` and returns a `MasterCap { id: UID, master_id: u64 }` with `key` and `store`. `rotation_delay_epochs` must be in `1..=30`.

Ids come from the `u64` counter mapped through a permutation of the 48-bit id space (xor-shifts by 24 and two odd multiplications mod 2^48). Distinct counters give distinct ids, counter 0 is the only preimage of id 0, and allocation aborts with `EMasterIdsExhausted` after the last 48-bit id. Ids look mixed but are public and the permutation is invertible; nothing depends on an id being unguessable.

Registration charges a flat fee through a native, `forwarding_address_register_cost_base`, on top of normal gas and the dynamic field storage cost. At 139 the fee is 1,000,000 gas units, about 1 SUI at a gas price of 1,000 MIST. The fee is paid as gas, so it goes to validators like any other gas. Records are never deleted, so the storage deposit is never rebated in practice.

### Resolution at the end of execution

Resolution is not Move code. `balance::send_funds` credits whatever address it is given and `TransferObjects` sets whatever owner it is given. Once Move execution has finished and the written objects and funds credits are known, the adapter walks both and reroutes every recipient that carries the magic:

1. Charge `forwarding_address_resolve_cost_base` for the recipient, once per address per transaction. If its variant exceeds `forwarding_address_max_variant`, fail.
2. Charge `forwarding_address_resolve_lookup_cost_base`, then read the master record at the transaction's assigned registry version. No record, or a paused record: fail.
3. If the master carries the magic, repeat from step 1 for it, up to `forwarding_address_max_hops` hops. Beyond that, fail.
4. Rewrite the recipient to the end of the chain: the object's owner, or the credit's target address and accumulator object id.

Charging happens before each read, so an unregistered id pays for its lookup. All charges go through the transaction's gas charger after Move execution, the same way the deny-list check charges its reads.

A record written earlier in the same transaction is not visible to resolution, because the read is bound to the registry version consensus assigned before execution. Registering and depositing to the new id in one programmable transaction fails, and the registration rolls back with it.

An object whose new owner is a forwarding address (`AddressOwner` or `ConsensusAddressOwner`, from `TransferObjects`, `transfer::public_transfer` or a coin transfer) ends the transaction owned by the master. A party object that grants a forwarding address permissions fails the transaction, since the address can never act.

`coin::send_funds(Gas, forwarding_address)` fails the transaction. The gas budget refund and gas charge location follow the gas coin's recipient and are set outside the resolver, and the master would net the coin's value plus the refund minus gas used, an amount known only after gas is charged, so no `ForwardingDeposit` could state what was paid. Payers split the amount off the gas coin instead.

After gas charging, a post-execution invariant check asserts that no written object is owned by a forwarding address and no accumulator write targets one.

### Events

The adapter emits these on Move's behalf. Each is charged like `event::emit` and counted against `max_num_event_emit`.

```move
public struct ForwardingDeposit<phantom T> has copy, drop { forwarding_address: address, master: address, amount: u64 }
public struct ForwardingTransfer has copy, drop { forwarding_address: address, master: address, object_id: ID }
```

Funds get one `ForwardingDeposit<T>` per forwarding address passed through and per coin type, with `amount` the sum of everything that passed through that address in the transaction. Splitting a payment into many credits therefore cannot exhaust the event limit, and an intermediate master in a chain sees what flowed through it. Objects get one `ForwardingTransfer` per hop.

The event carries the whole forwarding address, so the variant and payload survive losslessly. A reader slices bytes 16..32 for the payload; variant 0 defines no parse to depend on.

### Tracking deposits: the master's authenticated event stream

A payment app has to match every deposit to an invoice and must not depend on a fullnode telling the truth about which events happened. Sui already has authenticated event streams for this: `event::emit_authenticated<T>` emits an event and also records it in the `EventStreamHead` accumulator of a stream, a Merkle Mountain Range over the stream's events that is updated by the settlement transaction of every consensus commit and therefore committed in checkpoints. A light client reads the stream over gRPC `ListEvents` and verifies each event against the stream head using checkpoint proofs, with no trust in the serving node.

Move code can only write to the stream of its own package, since `emit_authenticated` takes the event type's package as the stream id. The adapter is not bound by that. With `forwarding_deposit_event_streams` on, the adapter records every `ForwardingDeposit<T>` it emits in the stream keyed by the master address: the same accumulator entry `emit_authenticated` would record, pointing at the event's index right after the transaction's Move events, charged at `event_emit_auth_stream_cost` per event. Each master therefore owns one stream that lists every deposit forwarded to it, across all of its forwarding addresses, in checkpoint order. Because the gas coin cannot be sent to a forwarding address, forwarded deposits are the only way funds reach a master through the feature, so the stream is a complete record of them.

A payment app subscribes with the Rust light client, `AuthenticatedEventsClient::stream_events(master)`, and for each verified `ForwardingDeposit<T>` reads the coin type from `T`, the amount, and the invoice or customer id from bytes 16..32 of `forwarding_address`. It needs no indexer and no per-address subscription; new forwarding addresses show up in the master's stream the first time they are paid. Ordinary event queries (gRPC `ListEvents` filtered by event type and sender, or GraphQL) keep working for apps that already trust their node, and an indexer can still key a table by `(master, payload)`.

Lifecycle events (`MasterRegistered`, `Paused`, `RotationFinalized` and the rest) are plain Move events on the `sui` package's stream, since `sui::forwarding_address` emits them itself. Whether `ForwardingTransfer` events for objects should also go into the master's stream is open.

Lifecycle events emitted by the Move module: `MasterRegistered { master_id, master, cap_id, rotation_delay_epochs }`, `Paused { master_id }`, `Unpaused { master_id }`, `RotationProposed { master_id, new_master, effective_epoch }`, `RotationCancelled { master_id }`, `RotationFinalized { master_id, master }`, `RotationDelayIncreased { master_id, rotation_delay_epochs }`.

### Lifecycle: pause and rotation

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

public fun is_forwarding_address(addr: address): bool;
```

Pause is immediate and either key can do it: the cap through `pause`, the current master through `pause_by_master`. While paused, deposits and transfers to the id fail at the end of execution like deposits to an unregistered id. Pausing an already paused id is a no-op. Only the cap can `unpause`.

Rotation is two-step. The cap proposes `new_master`, which must not carry the magic (`EForwardingAddressMaster`). The proposal records `effective_epoch = current_epoch + rotation_delay_epochs`. Anyone may call `finalize_rotation` once the current epoch reaches `effective_epoch`; before that it aborts with `ERotationNotDue`. Deposits keep crediting the old master while a rotation is pending. Either the cap or the current master can cancel a pending rotation. A new proposal replaces a pending one.

`rotation_delay_epochs` is chosen at registration in `1..=30` and can later only be increased, through `increase_rotation_delay`. Paused and pending are independent flags, so an id can be paused with a rotation pending.

Move abort codes: 3 `EMasterIdsExhausted`, 4 `EInvalidRotationDelay`, 5 `ENotMaster`, 6 `EForwardingAddressMaster`, 7 `ENoPendingRotation`, 8 `ERotationNotDue`.

### Failure behavior

Resolution failures (unregistered id, paused id, unsupported variant, chain longer than `forwarding_address_max_hops`, party object granting permissions to a forwarding address, gas coin sent to a forwarding address) are execution errors with no command index. The whole transaction fails and nothing is credited. On devnet they surface as `FeatureNotYetSupported`; dedicated `ExecutionFailureStatus` variants are an on-wire change that the Rust SDK types and gRPC proto must add first, and are required before testnet.

### Protocol configuration and rollout

| Setting                                       | Kind | Value at 139 (devnet)                 |
| --------------------------------------------- | ---- | ------------------------------------- |
| `create_forwarding_address_registry`          | flag | on since 132 (devnet only)            |
| `enable_forwarding_addresses`                 | flag | on (devnet only)                      |
| `forwarding_address_max_variant`              | u64  | 0                                     |
| `forwarding_address_max_hops`                 | u64  | 3                                     |
| `forwarding_deposit_event_streams`            | flag | on (devnet only), requires `enable_authenticated_event_streams` |
| `forwarding_address_resolve_cost_base`        | gas  | 52                                    |
| `forwarding_address_resolve_lookup_cost_base` | gas  | 512 * `obj_access_cost_read_per_byte` |
| `forwarding_address_register_cost_base`       | gas  | 1,000,000 gas units                   |

While `enable_forwarding_addresses` is off, the adapter leaves every recipient unchanged, the transfer check does not run, and transaction checks reject any transaction that takes the registry as an input, so nobody can register early. Deposits to forwarding-shaped addresses are ordinary deposits.

Once the flag is on, every transaction must have an assigned registry version. That requires the chain to reach a version that creates the registry before one that enables resolution, so the two flags live in different protocol versions and ship in different releases. On testnet and mainnet the same ordering applies: create the registry in one release, enable resolution in a later one.

A brake flag, `freeze_forwarding_addresses`, under which resolution fails for every forwarding address regardless of record state, is planned before testnet. It has to be a separate flag because turning `enable_forwarding_addresses` off would make the pattern an ordinary address again and strand funds.

### Interaction with other features

Deny list v2 checks the addresses that receive a regulated `Balance<T>` after execution. Resolution happens before the credit, so the master is what gets checked. Denying a master blocks deposits through all of its forwarding addresses; denying a forwarding address does nothing.

A vault withdrawal from object funds deposited to a forwarding address resolves like any deposit; the accumulator root and the registry are both implicitly read in that transaction.

In simulation and dry run the registry shows up in effects as a read-only consensus object, so simulated deposits report it like executed ones.

`register` and the lifecycle functions take the registry mutably, which places those transactions in the system-object-writer execution pool. A deposit sequenced after such a transaction in the same commit waits for its registry version.

### Client behavior

To derive an address: take `master_id` from `MasterRegistered` or the `MasterCap`, variant 0, and a 16-byte payload. Before sending to any address, check for the magic; anything sent to an address with the magic reaches its master if the id is registered and not paused, and fails the transaction otherwise. To find who a forwarding address pays, read the registry's dynamic field `master_id -> MasterRecord`. To track what was paid, subscribe to the master's authenticated event stream with `AuthenticatedEventsClient::stream_events(master)` and key each verified `ForwardingDeposit<T>` by its payload; or, trusting a node, query `ForwardingDeposit<T>` events and index them by `(master, payload)`.

## Rationale

The address has to be recognisable without a lookup, so that a wallet can warn before sending and execution can decide what to resolve. Nine magic bytes plus the variant byte give ten bytes that must line up for an address to be treated as a resolvable forwarding address, a collision probability of 2^-72 per key-derived address. 48 bits of id give 2^48 registrants and leave 16 bytes of payload for future variants that need structure.

Resolution runs outside Move because `TransferObjects` never enters Move, and a chain is a loop over registry reads. Doing the rewrite in the adapter after execution is what makes objects and chains reachable at all, and it means `balance::send_funds` and every existing transfer path work with forwarding addresses unchanged. The same resolver runs inside `test_scenario`, so Move unit tests see the same behavior.

The registry is an implicitly read system object because a payer should not have to know about it, so a deposit cannot declare it as an input. Consensus assigns the registry version to every transaction, in the same way as the accumulator root, so the read is deterministic, recorded in effects and reproduced on replay without adding a scheduling dependency to every transaction.

Ids are assigned by the registry, so there is no name to race for and no front-running. The counter is mixed only so that ids do not look sequential; nothing relies on them being secret.

Pause is immediate and either key can do it because pausing only stops deposits and never moves money, so a delay would only help an attacker, and letting the hot key pause means the brake can be hit without fetching the cap. Unpause is cap-only because if the master key could unpause, a stolen master key would undo the owner's pause and keep draining during the rotation delay. A stolen cap can keep an id paused, but a stolen cap already controls rotation; the remedy is a new id.

Rotation is two-step so that redirecting funds takes the cap plus the delay, while pausing or cancelling takes either key. A thief needs both keys to win, and the owner needs one to stop them. Anyone may finalize so the cap can go back in the safe after proposing.

The delay can only increase because a decrease would need its own timelock to stay safe against a stolen cap. A registrant who wants a shorter delay registers a new id.

The registration fee is paid as gas and goes to validators, so there is no treasury or distribution question. Records are permanent, so the fee also prices the permanent storage growth.

Deposits go into the master's authenticated event stream, rather than only into plain events, because the party that must act on a deposit (ship goods, credit an account) is exactly the party that should not have to trust a fullnode, and the master address is the one key under which all of its forwarding addresses naturally group. Keying the stream by master also means a payment app opens one subscription, not one per invoice.

Anything that would land at a forwarding address without resolution (an unregistered id, an unsupported variant, an over-long chain) fails the transaction, because nobody can sign for the address and funds left there would be lost. The payer keeps their funds and can retry.

## Backwards Compatibility

There is no on-wire type change. `ForwardingDeposit` and `ForwardingTransfer` are ordinary Move events, `MasterRecord` is an ordinary dynamic field, and the registry read appears in effects as a read-only consensus object, a shape that already exists.

Before protocol version 139, an address carrying the magic was an ordinary address. Any funds already held at such an address stay where they are and remain spendable by whoever holds the key; only new deposits and transfers after the flag turns on are rerouted. For a key-derived address the chance of carrying the magic is 2^-72, so with 2^32 addresses in existence the chance that any of them is affected is about 2^-40. Replay of pre-139 transactions keeps treating such addresses as ordinary, because the resolver runs only when the flag is on.

The registry object `0xfa` must exist before resolution can be enabled, so rollout to testnet and mainnet takes two protocol versions in two releases.

Dedicated `ExecutionFailureStatus` variants for the new failure modes are an on-wire change and will follow the two-release rule: add the variants under a devnet guard, then enable them after the Rust SDK types and gRPC proto have shipped them.

## Reference Implementation

- Registry as an implicitly read system object, version-pinned per transaction, protocol version 139 with `enable_forwarding_addresses`: https://github.com/MystenLabs/sui/pull/27989 (merged).
- Address format, registration, end-of-execution resolution of funds credits, `ForwardingDeposit` event, pause and two-step rotation: https://github.com/MystenLabs/sui/pull/28236.
- Forwarded deposits added to the authenticated event stream keyed by the master, behind `forwarding_deposit_event_streams`: https://github.com/MystenLabs/sui/pull/28261.
- Object rerouting with the `ForwardingTransfer` event and chaining bounded by `forwarding_address_max_hops`: https://github.com/MystenLabs/sui/pull/28246.

Relevant files: `crates/sui-framework/packages/sui-framework/sources/forwarding_address.move` (registry and lifecycle), `crates/sui-types/src/forwarding_address.rs` (address layout and record schema), `sui-execution/latest/sui-move-natives/src/forwarding_address.rs` (resolver), `sui-execution/latest/sui-adapter/src/static_programmable_transactions/execution/forwarding.rs` (adapter pass), and the design doc at `crates/sui-framework/design_docs/forwarding_addresses.md`.

## Security Considerations

Signature security is unchanged. A forwarding address is never a signer, and ordinary addresses keep the same key derivation. Owning a key whose address happens to carry the magic buys nothing, since everything sent to that address goes to the master.

A key-derived address collides with the magic with probability 2^-72. Grinding a key whose address carries the magic costs about 2^72 hashes, and grinding one for a specific master id costs 2^120. Because control of a forwarding address is worthless, these numbers only matter for accidental collisions.

Unregistered ids, paused ids, unsupported variants and over-long chains fail the transaction. Objects and unresolved credits to a forwarding address never survive execution. Turning the feature flag off would strand funds, which is why the brake is a separate flag.

Registration costs 1,000,000 gas units plus permanent storage, and the id space is 2^48. Lookups are charged before the read, including for misses, and the adapter-emitted events are charged and counted like Move events, so neither lookups nor events can be spammed for free.

Resolution reads a consensus-assigned registry version through the standard implicit-read mechanism. Every validator reads the same record, and replay reproduces the read from effects.

The master's event stream is written by the adapter, not by Move, and only with events the adapter itself emitted, so no third party can inject an entry into another master's stream. The stream head is committed in checkpoints like any accumulator, so a light client that verifies a `ForwardingDeposit` against it gets the same guarantee it gets for any authenticated event.

Two keys control an id, and the lifecycle is built so that losing either one is survivable. A leaked master key is contained by pausing (immediate, either key) and rotating (cap, delayed): pause, propose, wait, finalize, unpause. A leaked cap is caught because its rotation waits out the delay, during which the master cancels it. Losing both is not survivable, and nothing is designed for it.

Deny-list checks apply to the master, so an issuer of a regulated coin who needs to block a recipient denies the master.

## Open Questions

- Rotation delay bounds are `1..=30` epochs. Should `finalize_rotation` also require a transaction from the new master, proving the new key works before the cutover?
- Should a registrant be able to shorten the delay behind its own timelock, or is increase-only enough?
- Registration price: 1,000,000 gas units (about 1 SUI at a 1,000 MIST gas price) is the starting point. It should hurt for spam and not for a legitimate business.
- Brake semantics: should `freeze_forwarding_addresses` fail every deposit to a forwarding address, or only skip resolution and strand? The current proposal is to fail.
- Format: 48-bit id, 9-byte magic, 16-byte payload, collision margin 2^-72 per address. Revisit only before the format leaves devnet.
- Should `register` accept a master other than the sender, for example a custodian registering on behalf of a cold wallet? Today the master is always `ctx.sender()`, which also rules out a forwarding-shaped master by construction.
- Should `ForwardingTransfer` (objects) also be recorded in the master's authenticated stream, so a master can verify received objects the same way?
- Chaining is bounded at 3 hops with one summed `ForwardingDeposit` per address passed through. Is 3 the right bound, and should `propose_rotation` accept a forwarding-shaped `new_master`? Today it rejects one, so no chain can be built on chain.
- Can an object address (a shared or owned object's id) be a master, given nobody can sign for it and its balance is only reachable through object funds withdrawals?
- Do issuers of regulated coins need to deny a single forwarding address, or is denying the master enough?
- Should `MasterRecord` be readable from other Move packages (a `master_of(registry, id)` view), or is off-chain lookup enough for now?

## Copyright

Copyright (c) Mysten Labs, Inc.
