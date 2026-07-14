|   SIP-Number | |
|         ---: | :--- |
|        Title | PTB Publish-Result Interpolation |
|  Description | Enables later PTB commands to reference types and call targets from an earlier Publish command. |
|       Author | Greshamscode, @92GC |
|       Editor | <Leave this blank; it will be assigned by a SIP Editor> |
|         Type | Standard |
|     Category | Framework |
|      Created | 2025-06-25 |
| Comments-URI | |
|       Status | |
|     Requires | |

## Abstract

This proposal allows a PTB command to derive both a Move type argument and a Move-call target from an earlier `Publish` command. It enables a single transaction to publish a package, call its initialization functions, and use its newly defined types with existing protocols.

The referenced functions and types must exist in the successfully published package. Move continues to execute ordinary concrete types from verified bytecode.

## Motivation

The package ID created by `Publish` is not known while a PTB is being constructed. Consequently, later commands cannot:

1. call a function in the newly published package; or
2. use a type from that package as a generic argument to an existing package.

```typescript
const ptb = new Transaction();
const publication = ptb.publish({ modules, dependencies });

// Fails: the newly published package ID is unknown.
const [treasuryCap] = ptb.moveCall({
  target: `${???}::my_coin::create_currency`,
  arguments: [coinRegistry],
});

// Fails: the newly published type cannot be encoded yet.
ptb.moveCall({
  target: `${pasPackage}::policy::new_for_currency`,
  typeArguments: [`${???}::my_coin::MY_COIN`],
  arguments: [namespace, treasuryCap, false],
});
```

This forces multi-transaction workflows for token launches, permissioned assets, prediction markets, and protocols that generate proposal-specific types.

## PAS and Conditional Assets

PAS creates a policy for an existing currency type and requires its treasury capability:

```move
policy::new_for_currency<C>(
    namespace,
    treasury_cap: &mut TreasuryCap<C>,
    clawback_allowed,
)
```

A just-in-time conditional asset workflow therefore needs to:

1. publish the module defining `C`;
2. call that module to create and return `TreasuryCap<C>`;
3. pass `C` and the capability to PAS;
4. register the asset with a market or governance protocol; and
5. create the associated proposal.

Type interpolation solves step 3, while target interpolation makes step 2 callable.

## Specification

The SDK exposes publish-derived references equivalent to:

```typescript
const publication = ptb.publish({ modules, dependencies });

const coinType = ptb.typeFromResult(
  publication,
  "my_coin",
  "MY_COIN",
);

const [treasuryCap] = ptb.moveCall({
  target: ptb.targetFromResult(
    publication,
    "my_coin",
    "create_currency",
  ),
  arguments: [coinRegistry],
});

const [policy, policyCap] = ptb.moveCall({
  target: `${pasPackage}::policy::new_for_currency`,
  typeArguments: [coinType],
  arguments: [namespace, treasuryCap, false],
});
```

At the protocol level, a Move call's package reference supports either a static package ID or a reference to an earlier `Publish` command. Type arguments similarly support normal static type tags or a struct type whose package is derived from an earlier `Publish` command.

Publish-derived struct types may contain nested static or publish-derived type arguments, subject to the existing transaction-size and type-depth limits.

## Resolution

Before executing a publish-derived Move call, the execution adapter:

1. verifies that the reference identifies an earlier `Publish` command;
2. obtains the package ID created by that command;
3. resolves the requested module, function, and types;
4. validates visibility, type abilities, and the function signature; and
5. executes the call with normal concrete Move types.

An invalid command reference, module, function, type, or type parameter aborts the transaction.

## Rationale

This is transaction-level late binding of a package ID, not runtime type creation. The signed transaction commits to the package bytecode, dependencies, module names, function names, and type names. The only value derived during execution is the package ID created by the referenced `Publish` command.

Supporting both type arguments and call targets completes the publish-initialize-register workflow. Type-only interpolation is sufficient when the new type is immediately consumed by an existing package, but not when initialization must call a factory function in the newly published package.

## Non-Goals

This proposal does not:

- create types without publishing verified Move bytecode;
- expose types as Move values;
- add runtime generics or existential types;
- derive package references from arbitrary address-valued command results; or
- expose arbitrary objects created and transferred by module initializers.

Packages requiring same-PTB composition should expose public functions that return capabilities such as `TreasuryCap<C>` as command results.

## Implementation Impact

This proposal requires additive changes to:

- the PTB transaction model and BCS encoding;
- TypeScript and Rust transaction builders;
- transaction validation;
- package and type resolution during execution; and
- protocol-version gating, gas accounting, and tests.

No Move source-language or Move bytecode-format changes are required.

## Backwards Compatibility

Purely additive. Existing PTBs and static Move-call targets continue to work unchanged.

## Test Cases

- Publish a package and use one of its types in a call to an existing package.
- Publish a package and call one of its public functions later in the same PTB.
- Return a capability from the new package and pass it to an existing generic function.
- Resolve nested generic types containing a publish-derived type.
- Reject forward references and references to non-`Publish` commands.
- Reject missing modules, functions, types, and invalid type parameters.
- Preserve normal visibility and ability checking.

## Reference Implementation

To be developed.

## Security Considerations

- References may only point backward to an earlier successful `Publish` command.
- The executor derives the package ID; callers cannot substitute an arbitrary runtime address.
- Normal package linking, visibility, type-ability, and function-signature checks remain enforced.
- Resolution depth and size must remain bounded and metered.
- The transaction signature commits to every symbolic reference and to the published package contents.

## Copyright

Greshamscode 2025
