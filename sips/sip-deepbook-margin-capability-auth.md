|   SIP-Number | <Leave this blank; it will be assigned by a SIP Editor> |
|         ---: | :--- |
|        Title | Capability-Based Authority for DeepBook Margin MarginManager |
|  Description | Add object-capability authorization to MarginManager so it can be custodied and delegated by on-chain vaults without ceding withdrawal rights |
|       Author | Pika \<pika@cetus.zone, @RandyPen\> |
|       Editor | <Leave this blank; it will be assigned by a SIP Editor> |
|         Type | Standard |
|     Category | Application |
|      Created | 2026-07-11 |
| Comments-URI | <Leave this blank; it will be assigned by a SIP Editor> |
|       Status | <Leave this blank; it will be assigned by a SIP Editor> |

## Abstract

DeepBook Margin's `MarginManager` authorizes every state-changing operation by asserting that
the transaction sender equals a fixed `owner` address, and is created as a `key`-only shared
object with no `store` ability. Together these prevent the account from being custodied inside
another on-chain object and prevent any separation between "operate the position" and "withdraw
the assets." This SIP proposes adding an **object-capability** authorization path — an owner
capability and a scoped, non-withdraw operator capability — alongside the existing address-based
API. This lets shared-object vaults, structured products, and delegated keepers operate a margin
position (e.g. to run a delta-neutral hedge) without ever gaining custody of user funds, while
leaving DeepBook Margin's permissionless liquidation surface unchanged. The SIP also adds a
terminal `destroy` path so a wound-down manager and its capabilities can be fully deleted, and —
so the teardown composes — exposes DeepBook's existing empty-only `BalanceManager` deletion as an
authorized public entrypoint, leaving no orphaned on-chain state.

## Motivation

Concentrated-liquidity providers (Cetus DLMM and any CLMM/DLMM) carry directional inventory
risk: as price moves, the position accumulates one side of the pair. The standard mitigation is
to keep earning fees while opening an offsetting short/long that flattens the delta. DeepBook
Margin is the natural venue for that hedge on Sui — borrow the base asset, sell it on the order
book, and the resulting short offsets a long LP inventory. All the trading primitives already
exist (borrow/repay, on-book limit/market orders, reduce-only orders, take-profit/stop-loss,
permissionless liquidation).

The blocker is not a trading primitive; it is the **ownership model**. A non-custodial vault
wants to hold the hedge account and let a delegated agent operate it, under a guarantee — enforced
by the Move type system, not by trust — that the agent can rebalance but can never withdraw the
user's principal. This pattern is already in production. LeafSheep, a non-custodial vault
application, custodies Cetus DLMM LP positions through its open-source `cdpm` (Cetus DLMM
Position Manager) contract. Here "vault" denotes per-position custody — one shared object per
position, holding a single depositor's assets under an owner plus a set of delegated agents —
rather than a pooled, share-issuing vault. Because the Cetus `Position` object has the `store`
ability, the vault locks it inside that shared object and mediates access through its own
owner/agent/protocol permission tiers; Cetus operations are authorized by *possessing* the
position, not by the transaction sender's identity. Withdrawal authority and operating authority
are cleanly separable, so a depositor can delegate active management to a keeper without ceding
custody.

DeepBook Margin's `MarginManager` cannot participate in this pattern, for two independent reasons
in the deployed contract (`packages/deepbook_margin`):

1. **No `store` ability, and force-shared.** `MarginManager<Base, Quote>` is declared `has key`
   only and is immediately `transfer::share_object`-ed on creation. A `key`-only shared object
   cannot be embedded in, or owned by, another object, so there is nothing a vault can custody.

2. **Authority is sender-identity, not object-possession, and all-or-nothing.** Every
   state-changing entrypoint — `deposit`, `withdraw`, `borrow_base`/`borrow_quote`,
   `repay_base`/`repay_quote`, conditional-order management, referral, register/unregister — asserts
   `ctx.sender() == self.owner`, and the internal trading accessor used by all `pool_proxy` order
   placement re-checks the same. The `owner` field is fixed at creation to `ctx.sender()` and has
   no transfer or rotation function. Because a shared object or smart contract has no private key
   and can never be `ctx.sender()`, a vault can never operate the account on a user's behalf; and
   because the same check gates both trading and withdrawal, whoever is `owner` can always drain
   the account. There is no way to express "may operate, may not extract."

The result is that the custody guarantee already shipped for the Cetus leg — *agents operate,
only owners withdraw* — cannot be expressed for a DeepBook Margin position. This SIP closes that
gap.

## Specification

The change adds a capability-authorized API to `deepbook_margin` and leaves the existing
address-authorized API in place.

### Capability objects

Two owned, storable capability types are introduced, each pinned to a single manager:

```move
public struct MarginManagerOwnerCap has key, store { id: UID, manager_id: ID }
public struct MarginManagerOperatorCap has key, store { id: UID, manager_id: ID, epoch: u64 }
```

- The **owner capability** conveys full authority: withdraw, unregister, destroy, referral
  configuration, and minting/revoking operator capabilities.
- The **operator capability** conveys a scoped authority set: `borrow`, `repay`, all order
  placement (limit, market, reduce-only, modify, cancel), conditional orders (TP/SL), and
  optionally `deposit`. It MUST NOT authorize `withdraw`, `unregister`, or `destroy`.

The manager retains a monotonically increasing `operator_epoch` counter. An operator capability
is valid only while `cap.epoch == manager.operator_epoch`; the owner revokes all outstanding
operator capabilities by incrementing the counter.

### Authorization

A `validate_cap` check replaces the sender-identity check on the capability-authorized paths:

- Owner-gated functions accept `&MarginManagerOwnerCap` and assert `cap.manager_id == self.id()`.
- Operator-gated functions accept `&MarginManagerOperatorCap` and assert
  `cap.manager_id == self.id() && cap.epoch == self.operator_epoch` and that the requested action
  is in the operator-allowed set.

The existing address-based functions continue to authorize via `ctx.sender() == self.owner` for
accounts created through the existing constructor.

### Entrypoints

- **Creation:** a new constructor returns the owner capability to the creator instead of binding
  `owner` to `ctx.sender()`; the `MarginManager` is still shared.
- **Delegation:** `mint_operator_cap(&MarginManagerOwnerCap, ...) -> MarginManagerOperatorCap` and
  `revoke_operator_caps(&MarginManagerOwnerCap, &mut MarginManager)` (increments `operator_epoch`).
- **Capability-authorized variants** of each owner-gated `margin_manager` entrypoint and each
  `pool_proxy` trading entrypoint, taking the appropriate capability in place of the implicit
  sender check. These follow the package's existing versioned-API convention for adding
  entrypoints without changing deployed signatures.

### Lifecycle and destruction

A capability-created `MarginManager` MUST be destroyable once it holds no assets and has no open
position, leaving no orphaned on-chain state. Today the account can only be emptied and
de-registered (`unregister_margin_manager` removes the registry entry but leaves the shared
object in place forever). This SIP adds a terminal `destroy` entrypoint that consumes the
`MarginManager` by value and, presenting a matching `MarginManagerOwnerCap`, requires the account
to be fully wound down:

- **No open position (debt):** `borrowed_base_shares == 0`, `borrowed_quote_shares == 0`, and
  `margin_pool_id` is none.
- **No open orders:** no resting orders on the book — i.e. the balance locked in orders is zero.
  This check is **additional** to what `unregister_margin_manager` performs today. The existing
  free-balance getters (`base_balance`/`quote_balance`) read only the `BalanceManager`'s *free*
  balance; funds resting in open orders are locked outside it (see `calculate_assets`, which sums
  `pool.locked_balance` with the free balance). A destroy that checked only free balances could
  therefore delete a manager that still has live orders referencing its `BalanceManager`, so
  `destroy` MUST assert no locked/open-order balance as well.
- **No assets:** zero free base, quote, and DEEP balance (combined with the no-open-orders check,
  this means zero total assets).

On success `destroy` also de-registers the manager from `margin_registry`, burns the presented
owner capability so no capability outlives its manager, tears down the wrapped
`deepbook::balance_manager::BalanceManager`, and deletes the object's `UID`.

Outstanding operator capabilities for a destroyed manager become permanently inert (they can
never satisfy `validate_cap` against a non-existent manager) and may be discarded by their
holders. Destroying a shared object is permitted by the Sui runtime; the entrypoint takes the
`MarginManager` by value to do so.

### Composable BalanceManager destruction

`MarginManager::destroy` must tear down the wrapped `deepbook::balance_manager::BalanceManager`,
and integrators composing their own accounts want the same ability. The teardown logic already
exists — `balance_manager::delete` unpacks the object and calls `balances.destroy_empty()`, which
aborts unless the balance bag is empty, so it already enforces "destroy only when no assets
remain." The gap is **visibility**: `delete` is `public(package)` (documented as being for the
temporary `BalanceManager`s used in direct pool swaps), so no other package — including
`deepbook_margin` — can call it.

This SIP proposes exposing an **authorized public destroy for an empty `BalanceManager`** on the
`deepbook` package, reusing the existing `destroy_empty` guard so no funds can ever be dropped. It
consumes the `BalanceManager` by value and deletes it only if its balance bag is empty.
Authorization is by possession — the caller must hold the `BalanceManager` by value, which for an
owned account only its owner can, and which `MarginManager::destroy` satisfies after unpacking its
own struct (the wrapped manager's `owner` is the `MarginManager`'s object address, so no
sender-based check applies). The exact authorization shape (possession-only versus an additional
owner/cap proof to guard against griefing a *shared* `BalanceManager`) is an open question for the
DeepBook team; see Rationale.

### Unchanged surfaces

- The `MarginManager` remains a **shared** object.
- `liquidate` and `execute_conditional_orders` remain permissionless and unchanged; they do not
  perform an owner check today and continue not to.
- The accounting, risk-ratio, interest-accrual, and liquidation engines are untouched. The
  `deepbook::balance_manager::BalanceManager` and its caps are unchanged except for the single
  additive change of exposing its already-existing empty-only `delete` as an authorized public
  entrypoint (see *Composable BalanceManager destruction*).

### Registry interaction

`margin_registry` currently tracks accounts as `Table<address, VecSet<ID>>` keyed on
`ctx.sender()`, with a per-owner account-count cap. Because a capability is transferable, the
"owner address" is no longer stable. This SIP proposes keying registration on the creator address
captured at mint time (preserving the existing per-creator cap semantics); alternatives are
discussed in Rationale.

## Rationale

**Why a capability, not `store` on the manager itself.** Giving `MarginManager` `store` and
letting integrators embed an *owned* manager would break permissionless liquidation: a liquidator
could no longer obtain `&mut MarginManager` for an account owned inside a shared vault, forcing
every integrator to re-expose a solvency-critical `liquidate` passthrough. Keeping the manager
shared and moving authority into a separate capability object preserves liquidation reachability
in the protocol, where it belongs. Cetus positions have no protocol-level permissionless
liquidation, which is why direct embedding is safe there but not here.

**Why this is a small change.** `MarginManager` already wraps DeepBook's `BalanceManager`, which
is an object-capability design (`has key, store`; `TradeCap`/`DepositCap`/`WithdrawCap` held
internally by the manager). The sender-identity assertion is a thin layer added on top of an
already-capability-based core; the accounting and risk logic never inspects `ctx.sender()`. The
proposal replaces that layer and adds parallel entrypoints, rather than restructuring any engine.

**Why split owner vs operator.** A single capability would restore delegation but not the
non-custodial guarantee that motivates the SIP. The two-tier split is the minimal shape that lets
a vault hand a keeper the ability to hedge while structurally withholding withdrawal.

**Registry-keying alternatives.** Keying on the current capability holder would require tracking
transfers on-chain and is rejected as over-complex; dropping per-owner accounting entirely is
possible but changes an existing anti-spam bound. Keying on creator-at-mint preserves current
behavior with no new state.

**BalanceManager destroy authorization.** The empty-only guard (`destroy_empty`) protects funds,
but the account object itself carries an `allow_listed` set and referral wiring, so deleting
someone else's `BalanceManager` — even an empty one — is a griefing vector if the object is
shared. Possession-only authorization is sufficient and simplest for the common *owned*-account
case (and for `MarginManager::destroy`, which holds the wrapped manager by value), but the DeepBook
team may prefer to additionally require an owner proof or the owner capability to cover shared
`BalanceManager`s. The reference direction is possession-only, with the stricter option left open.

## Backwards Compatibility

Fully backwards compatible. All existing `public` signatures are preserved; the capability model
is added as new entrypoints and new object types alongside the deployed address-based API, using
the package's existing convention for versioned additions. Accounts created through the existing
constructor continue to authorize by sender identity and are unaffected. Integrators opt in by
creating accounts through the new constructor. No migration of existing on-chain state is
required.

The `deepbook` package change is likewise additive: the existing `public(package)` `delete`
retains its current visibility for the package's internal callers, and the proposed authorized
public destroy is a new entrypoint. No existing `BalanceManager` behavior changes.

## Test Cases

- An owner capability can perform withdraw, borrow, repay, trade, unregister, and destroy on its
  manager; a capability whose `manager_id` does not match is rejected.
- An operator capability can borrow, repay, place/cancel/modify orders, place reduce-only orders,
  and manage conditional orders, but withdraw, unregister, and destroy abort.
- Revocation: after `revoke_operator_caps`, a previously minted operator capability is rejected on
  every operator-gated path; a freshly minted one succeeds.
- Permissionless `liquidate` and `execute_conditional_orders` succeed against a capability-created
  manager with no capability presented, identically to an address-created manager.
- A shared-object vault holding an owner capability and issuing operator capabilities to a
  whitelist can hedge on behalf of a depositor while no path allows assets to leave the vault
  except through the owner-gated withdraw.
- `destroy` succeeds on a fully wound-down manager (no debt, no balance, no open orders,
  de-registered) presenting a matching owner capability, and leaves no object behind; it aborts if
  any debt, balance, or open order remains, or if the owner capability does not match.
- The authorized public `BalanceManager` destroy succeeds on an empty `BalanceManager` and leaves
  no object behind; it aborts if any asset balance remains. `MarginManager::destroy` uses it to
  delete the wrapped manager as part of a full teardown.

## Security Considerations

- **Capability custody.** Authority follows possession of the capability object. Integrators must
  custody the owner capability with the same care as a private key; locking it inside a shared
  object with mediated access (as this SIP's motivating vault does) is the intended pattern.
- **Operator scope enforcement.** The security guarantee depends on the operator capability being
  unable to reach any withdraw, unregister, or destroy path. The action-allow-set MUST be enforced
  at every capability-gated entrypoint, and reviewers should confirm no operator-gated function
  transitively reaches asset extraction.
- **Revocation liveness.** Epoch-based revocation invalidates all outstanding operator
  capabilities at once. Integrators relying on a specific operator capability should treat
  revocation as owner-initiated and re-mint as needed.
- **Liquidation unaffected.** Because the manager stays shared and the permissionless paths are
  unchanged, capability-based accounts are liquidated on exactly the same terms as existing
  accounts; solvency enforcement is not weakened.
- **No new privileged actor.** The change introduces no admin authority over user accounts; owner
  capabilities are minted only to the account creator.

## Copyright

Copyright and related rights waived via [CC0](../LICENSE.md).
