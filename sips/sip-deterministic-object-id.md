|   SIP-Number | - |
|         ---: | :--- |
|        Title | Deterministic Object ID Creation With Salt |
|  Description | Introduce `new_with_salt` and `new_with_salt_as` to create Sui objects with predictable, pre-computable IDs. |
|       Author | Igwe, @theigwe |
|       Editor | - |
|         Type | Standard |
|     Category | Framework |
|      Created | 2026-03-28 |
| Comments-URI | - |
|       Status | - |

## Abstract

This SIP introduces two new functions to the Sui Move framework — `object::new_with_salt` and
`object::new_with_salt_as` — that allow objects to be created with deterministic, pre-computable
IDs derived from a creator address and a caller-supplied salt value. The scheme enables counterfactual instantiation patterns on Sui.

## Motivation

Currently, Sui object IDs are derived as:

```
Hash(0xf1 || tx_digest || ids_created_counter)
```

This binds every object ID to the specific transaction in which it is created, making the ID
unknowable before execution. As a result, it is impossible to send funds, configure permissions,
or establish references to an object before it exists — a pattern commonly known as counterfactual
instantiation.

Counterfactual instantiation is a fundamental primitive for many DeFi and infrastructure use
cases, including:

- **Pre-funding**: depositing assets into a wallet or vault address before the controlling object
  is deployed
- **Deterministic protocol deployments**: ensuring that a protocol's core objects always live at
  well-known, auditable addresses across networks
- **Factory patterns**: a factory contract that creates child objects at addresses that can be
  computed off-chain by any observer, enabling trustless integrations before deployment

Without this primitive, developers must resort to workarounds such as two-step initialisation flows
or wrapper registries, adding complexity and gas overhead.

## Specification

### ID Derivation

A new hashing intent scope is introduced:

```
HashingIntentScope::SaltedObjectId = 0xf2
```

The ID is derived as:

```
ObjectID = Hash(0xf2 || creator_address_bytes || salt_bytes)
```

The same `creator` and `salt` always produce the same `ObjectID`, regardless of the transaction
in which the object is created.

### New Move Framework Functions

Two new public functions are added to `sui::object`:

#### `new_with_salt`

```move
/// Create a UID with a deterministic ID derived from the transaction sender and `salt`.
/// The same sender + salt always produce the same object ID.
/// Aborts if a live object with the computed ID already exists on-chain.
public fun new_with_salt(salt: vector<u8>, ctx: &mut TxContext): UID
```

The creator is implicitly `ctx.sender()`. No explicit creator parameter is required or accepted,
which eliminates the possibility of salt-squatting across address namespaces.

#### `new_with_salt_as`

```move
/// Create a UID with a deterministic ID derived from `creator` and `salt`, authorized by `_proof`.
/// `_proof` must be the UID of an object whose address equals `creator`.
/// Possession of the object proves the right to occupy that address's salt namespace.
/// Aborts if `_proof` does not match `creator`, or if a live object with the computed ID
/// already exists on-chain.
public fun new_with_salt_as(
    creator: address,
    _proof: &UID,
    salt: vector<u8>,
    _ctx: &mut TxContext,
): UID
```

This function enables the factory pattern: a contract (factory) can create objects whose IDs are
scoped to the factory's own address by passing a reference to its own `UID` as the authorization
proof. Move's type system guarantees that a `&UID` cannot be forged — only a module that has
access to the object can produce such a reference.

### Collision Detection

Because salted IDs are not derived from a per-transaction counter, they are not provably
collision-free by construction. A post-execution backing-store check is performed in
`TemporaryStore` before effects are committed:

- For each salted ID created during execution, if an object with that ID already exists on-chain
  (and was not consumed in the same transaction), execution aborts with a new
  `SaltedObjectIdAlreadyExists` error.

Salted IDs are tracked separately from regular IDs in `ObjectRuntimeState` to avoid imposing the
backing-store check on regular object creation, which is provably unique.

### Protocol Version Gate

The feature is activated in protocol version 121. It is enabled on Devnet and Testnet at
activation; Mainnet activation is deferred pending community feedback.

A new gas cost parameter `object_new_with_salt_cost_base` is introduced, initially set to `260`
(equivalent to the existing `object_record_new_uid_cost_base`).

## Rationale

### Why not a single function with an explicit `creator` parameter?

An earlier thought on The design used a single `new_with_salt(creator, salt, ctx)` with an assertion
`ctx.sender() == creator`. This wouldn't stick because:

1. It is functionally equivalent to using `ctx.sender()` implicitly — the explicit parameter adds
   no expressive power for the direct-call case.
2. Factory contracts cannot pass `ctx.sender()` as the `creator` for their own namespace because
   `ctx.sender()` is always the original transaction signer, not the calling contract's address.

Splitting into two functions gives each case a clean API: `new_with_salt` for the simple
sender-scoped case, and `new_with_salt_as` for the factory-delegation case.

### Why `&UID` as the authorization proof?

`&UID` is the idiomatic unforgeable capability in Sui Move — it is already used throughout the
framework for dynamic fields, transfer-to-object, and similar patterns. Requiring `_proof` to be
a `&UID` whose address matches `creator` means:

- No new capability types are needed.
- Authorization is checked entirely within the Move type system; no native code is required.
- The pattern is familiar to existing Sui Move developers.

### Why post-execution collision detection?

The native function has no access to backing storage. Performing the check post-execution (but
pre-commit) in `TemporaryStore` is consistent with how other execution invariants are enforced in
Sui and avoids coupling the native layer to storage.

### Namespace squatting

Because `new_with_salt` uses `ctx.sender()` implicitly and `new_with_salt_as` requires possession
of the creator object, neither function allows one party to pre-occupy another party's
`(creator, salt)` slots.

## Backwards Compatibility

This change is purely additive:

- No existing functions are modified or removed.
- The new `HashingIntentScope::SaltedObjectId = 0xf2` discriminant does not conflict with any
  existing discriminants (`0xf0`, `0xf1`).
- The new `SaltedObjectIdAlreadyExists` error kind is additive; existing error kind match arms are
  unaffected.
- Protocol version gating ensures no behaviour change on networks that have not activated
  version 121.

## Test Cases

### Move unit tests (`object_salted_id_tests.move`)

- `test_deterministic` — same sender and salt in two calls produce the same object ID.
- `test_different_salt` — same sender with different salts produce different object IDs.
- `test_different_creator` — two different creator UIDs with the same salt produce different
  object IDs (exercises `new_with_salt_as`).

### Transactional tests

- `salted_objects/basic.move` — end-to-end creation and transfer of a salted object.
- `salted_objects/collision.move` — re-creation of a salted ID after the original object is
  deleted.

## Reference Implementation

https://github.com/MystenLabs/sui/pull/salted-id-intent

## Security Considerations

### Salt exhaustion

A given `(creator, salt)` pair can only ever produce one live object. If the object is deleted,
the slot becomes available again. Users should treat their salt space as a finite, persistent
namespace and choose salts with sufficient entropy to avoid accidental collisions.

### Griefing via `new_with_salt_as`

An attacker cannot occupy another party's `(creator, salt)` slot via `new_with_salt_as` without
first obtaining (or forging) a `&UID` reference whose address matches `creator`. Forging a `&UID`
is not possible within the Move type system. Direct possession of the creator object (or a module
that exposes it) is required.

### Front-running

Because salted IDs are deterministic and publicly computable, a front-runner could observe a
pending transaction and attempt to create the same object first. The collision check will cause
the victim's transaction to fail. This is mitigated in practice by the sender-scoped namespace of
`new_with_salt` (only the sender can create objects in their own namespace) and the object-proof
requirement of `new_with_salt_as`.

### No impact on existing object ID uniqueness

Regular object IDs (`0xf1` scheme) are unaffected. The salted scheme uses a distinct discriminant
(`0xf2`) and a separate collision-detection path, so there is no interaction between the two.

## Copyright

[CC0 1.0](../LICENSE.md).
