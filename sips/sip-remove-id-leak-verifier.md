|   SIP-Number | <Leave this blank; it will be assigned by a SIP Editor> |
|         ---: | :--- |
|        Title | Remove the ID Leak Verifier |
|  Description | Remove the Sui Move ID Leak Verifier so that a `UID` extracted from an object can be repacked into a new object. |
|       Author | Manos Liolios, Todd Nowacki |
|       Editor | <Leave this blank; it will be assigned by a SIP Editor> |
|         Type | Standard |
|     Category | Core |
|      Created | 2026-08-10 |
| Comments-URI | <Leave this blank; it will be assigned by a SIP Editor> |
|       Status | <Leave this blank; it will be assigned by a SIP Editor> |

## Abstract

The Sui bytecode verifier rejects any package whose code stores anything other than a freshly-minted `UID` in the `id` field of an object. This SIP proposes removing that check, so that a `UID` extracted from an object via unpack can be reused as the `id` of a new object, including an object of a different type and/or in a different module than the original.

The change is intentionally narrow: it does not introduce any new way to resurrect a deleted ID. Existing rules around `object::delete` and address minting are unchanged. What it allows is keeping a `UID` alive across unpack / pack — possibly through intermediate storage — without creating a new underlying address.

## Motivation

The verifier requires every object to be packed using a freshly-minted `UID`: once any object exists at `X`, no future Move code can produce another object at `X`, even when the originating module legitimately holds the underlying `UID`. Module authors who want to swap an object's backing instance have to mint a fresh `ObjectID`.

This prevents patterns where an `ObjectID` represents a long-lived *handle* whose backing instance is allowed to evolve, e.g. for in-place type migration. Upgrading `PositionV1` to `PositionV2` while preserving the position's `ObjectID`.

The verifier change alone unlocks any unpack-then-pack pattern in a module that has custody of the `UID`.

The verifier is also redundant. Every on-chain property it protects is already enforced at runtime. What it costs is a dataflow pass in the verifier, a second implementation of the same analysis in the Move compiler, and a hand-maintained allow-list of framework functions that both must keep in sync. Removing it is a straight simplification.

## Specification

### Verifier

After this change, there is no longer a special-case requirement that `id: UID` for an object must originate from a fixed allow-list of framework calls.

### Patterns enabled

```move
// In-place repack at the same `UID`. The destination may be a fresh `A`, or any
// other key-having struct in a module that has custody of the `UID`.
let A { id, .. } = a;
let a2 = A { id, .. };  // or `let b = B { id, .. };`
```

## Rationale

The runtime already enforces every on-chain safety property the verifier was protecting; the verifier only upholds an off-chain ergonomic invariant — that an ID's type is constant — which this SIP intentionally relaxes.

After this change, **whether a `UID` ever escapes its originating object becomes a per-package decision rather than a global protocol restriction**. Only the defining module of a `key` struct can unpack it, so an ID stays bound to its original type unless that module exposes a path that yields the `UID` (returning it, storing it in a public DF). Once loose, any module with custody can pack it into one of its own types.

The gating decision belongs to the **originating module**. This also means that type evolution should not be expected for known system types (e.g. `Coin`)

## Backwards Compatibility

### On-chain

Strictly compatible. Every Move source program that compiles today continues to compile, and every published package continues to verify and execute under its pinned execution version.

### Off-chain

**`ObjectID -> StructTag` mutability is not an entirely new property in Sui** — it already holds for dynamic field objects today. The address of a `Field<Name, Value>` is derived from `(parent_address, type<Name>, bcs(name))`; `Value` is not part of the address. So `df::add(parent, name, V1)` followed by `df::remove<V1>` and `df::add(parent, name, V2)` reuses the same child `ObjectID` with a different `StructTag`. The Sui-maintained off-chain stack — `sui-indexer-alt`, GraphQL, gRPC, JSON-RPC — already accommodates this.

What changes is the *scope* of this property. Today the mutation is restricted to DF child objects; after this SIP, it can also apply to top-level objects whose originating module exposes a path that lets the `UID` escape into a struct of a different type. A package that exposes no such path is indistinguishable from today, and same-type repack at the same `UID` is invisible to off-chain consumers — it looks like a normal mutation.

## Request for Feedback

This SIP goes through the SIP process because we believe **the only material change is widening the existing `ObjectID -> StructTag` mutability story to top-level objects**, but we want builders to confirm. The Sui-maintained off-chain stack already handles this property for DF objects; the risk we cannot survey from the inside is third-party services that may have assumed top-level objects were exempt.

We are explicitly asking for feedback on:

- **Off-chain consumers we have not enumerated** — indexers, RPCs, explorers, wallets, or SDKs that key caches or routing decisions on `ObjectID` alone with an implicit type-stability assumption.
- **On-chain patterns relying on type-per-ID constancy**
- **Anything we have classified as out of scope that you think should be in scope** (or vice versa).

## Reference Implementation

To be provided as a follow-up PR against [`MystenLabs/sui`](https://github.com/MystenLabs/sui) once this SIP is reviewed and the design has been aligned with feedback.

## Security Considerations

- **Off-chain scope change.** `ObjectID -> StructTag` mutability, already a property of DF child objects, is extended to top-level objects whose originating module opts in. Not a protocol vulnerability, but the most likely source of user-visible incidents in services that previously assumed top-level objects were exempt, and the reason this proposal goes through the SIP process.
- **No new UID-creation capability.** Repack preserves an existing `UID`; the rules around `object::delete`, `fresh_object_address`, and `new_uid_from_hash` are unchanged. In particular, this SIP does not enable resurrection of deleted objects, nor owned to shared promotion at an existing address (the runtime `share_object` guard requires the `ObjectID` to be freshly minted in the current transaction).

## Copyright

[CC0 1.0](../LICENSE.md).
