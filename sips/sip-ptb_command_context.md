# SIP-70: Current Command Range Hash

## Summary

Add one native function on `sui::tx_context`:

```move
public fun current_command_range_hash(ctx: &TxContext, additional_commands: u64): vector<u8>
```

This returns a versioned hash of a given sequential range of the current PTB commands.

This let's a contract lock in the part of a PTB it cares about,
while leaving the rest of the PTB open for wallets, solvers, sponsors, or other
composition.

This is more useful than a whole-PTB hash for smart accounts and governance,
because the authorized intent can be fixed without forcing the whole transaction
to be fixed.

## Motivation

Apps currently need execution wrappers for every new function they want to call.
This is messy UX and prevents JIT execution.

This lets smart accounts, DAOs, and account-abstraction systems act as wallets
and interact seamlessly without hard-coded pre-deployed wrappers.

`current_command_range_hash(ctx, additional_commands)` keeps the primitive at
the PTB layer:

- fixed intent commands can be committed to
- solver/wallet commands before or after the range can stay open
- Move receives only an opaque hash
- no PTB introspection is exposed

This is idiomatic because it makes fixed intents and open solver execution
composable without leaking PTB abstractions into Move.

## Specification

### Move API

```move
module sui::tx_context {
    /// Returns a hash of the current command and the next `additional_commands`
    /// commands.
    /// Output: [version_byte | blake2b256_hash] (33 bytes).
    public fun current_command_range_hash(
        _self: &TxContext,
        additional_commands: u64,
    ): vector<u8>;
}
```

The current command is the PTB command that is currently executing this native.
For example, if command 4 calls a smart account function that calls
`current_command_range_hash(ctx, 2)`, the hash covers commands 4, 5, and 6.

The current command is included in the hash.

`additional_commands = 0` hashes the current command only.

Because the current command is included, the expected hash should come from
authenticated object state, such as an approved account or DAO intent. It should
not be passed as a pure argument to the command being hashed.

### Output Format

```text
[version_byte | blake2b256_hash]
```

- version `0x01` = current command range hash scheme
- total output: 33 bytes

If fewer than `additional_commands` commands remain after the current command,
the function returns a domain-separated unavailable hash, not an abort. The
unavailable hash must not collide with any valid command range hash. Callers
should treat it as a normal hash comparison failure.

This lets contracts safely write:

```move
let actual = tx_context::current_command_range_hash(ctx, additional_commands);
assert!(
    actual == expected_hash,
    EHashMismatch,
);
```

without also needing to introspect PTB length.

### What Is Hashed

The hash commits to the selected contiguous command range only.

For every command in the range, the encoder commits to:

- command kind
- package, module, function, and type arguments for Move calls
- command-specific data for non-Move-call commands
- argument count and argument structure
- result flow between commands inside the range
- imported values from outside the range, as imports

All strings, byte blobs, and lists are length-framed. That means the hash input
includes each field's length before the field bytes, so two different command
encodings cannot collide by concatenating to the same byte string.

### What Is Not Hashed

The hash does not commit to:

- sender/caller address
- sponsor address
- signatures
- transaction digest
- gas budget
- gas price
- gas coin object ID
- gas coin version
- object versions
- commands before the selected range
- commands after the selected range
- absolute command position

The VM may use the current command index internally to compute the range, but
the API exposes only the hash. It does not expose position, depth, frame kind, or
whether the caller is inside any higher-level application abstraction.

### Argument Normalization

Each PTB argument is normalized before hashing:

| Argument Type | What Gets Hashed | Rationale |
| --- | --- | --- |
| `GasCoin` | marker only | gas coin identity is sender-dependent and should not be part of intent |
| `Pure(bytes)` | exact bytes | fixed parameter value |
| `SharedObject` | ObjectID + mutability mode | mutability changes lock/call semantics, so it is hashed; object versions are not stable |
| `ImmOrOwnedObject` | ObjectID | version can drift between authorization and execution |
| `Receiving` | ObjectID | version can drift |
| result inside range | relative command/result index | commits to flow inside the locked range |
| result before range | import slot | allows solver/wallet setup before the locked range |

Direct PTB inputs are fixed. If a command in the range uses a direct object or
pure input, that value is part of the hash.

If a command in the range uses a value produced by a command before the range,
that value is encoded as an import. The hash commits that an imported value is
used, and where it is used, but not to the full command sequence that produced
it.

Import slots are assigned by first use inside the range. Reusing the same
external value reuses the same import slot. Different external values get
different import slots.

This is the key composability property: a solver can do any number of setup
commands first, then route values into the fixed range, without changing the
range hash.

### Hash Construction

Conceptually:

```text
range_hash = 0x01 || Blake2b256(
    "SUI_CURRENT_COMMAND_RANGE_HASH"
    || additional_commands
    || for each selected command in order:
        Blake2b256(
            command_kind
            || length_framed(command_specific_data)
            || normalized_arguments
        )
)
```

The concrete encoder should be semantic and versioned, not raw BCS of the PTB
Rust type. Future PTB shape changes can then be handled by the encoder instead
of changing the Move API.

### Example

The wallet or solver can build:

```text
0. solver setup command
1. solver setup command
2. smart_account::execute_intent(account, intent_id, 2, ctx)
3. fixed intent command
4. fixed intent command
5. solver settlement command
```

Inside command 2, the smart account checks:

```move
let expected_hash = smart_account::approved_hash(account, intent_id);
let actual = tx_context::current_command_range_hash(ctx, 2);
assert!(actual == expected_hash, EHashMismatch);
```

The hash covers commands 2, 3, and 4.

Commands 0, 1, and 5 are not hashed. The solver can change them without
changing the authorized intent, as long as the locked range still receives the
right imported values and has the same command structure.

The expected hash is loaded from the smart account's approved intent state. It
is not a caller-supplied pure argument, so the hash does not require a fixed
point.

## Why Not Full PTB Hash

A full PTB hash is too rigid for the main use case.

Smart accounts and governance usually want to authorize the important part of a
transaction, not the exact gas setup, solver route, sponsorship details, or
settlement tail.

A range hash lets the authorized part stay fixed while solver, wallet, and
sponsorship logic stays flexible.

## Implementation Notes

This can be implemented with the same broad machinery as a structural digest,
but scoped to the current command range:

1. Store or expose the current `ProgrammableTransaction` to `TxContext` during
   execution.
2. Track the currently executing command index internally in the PTB executor.
3. When the native is called, hash the inclusive range
   `[current_index, current_index + additional_commands]`.
4. Encode in-range result references relatively.
5. Encode references to earlier results as imports.
6. Return the unavailable hash if the requested range runs past the end.
7. Charge base gas plus a per-byte/per-command cost for the hashed range.

The current command index is execution metadata. It is not returned to Move and
is not part of the public API.

## Security Considerations

- VM-computed and read-only
- order-sensitive within the selected range
- flow-sensitive within the selected range
- no sender/caller address or gas coin identity in the hash
- no PTB introspection
- no way to ask for absolute PTB position
- commands outside the range remain intentionally open

Contracts should compare the returned hash against an expected hash that was
computed off-chain using the same versioned encoder.

## Backwards Compatibility

Purely additive. This adds one new native function behind a protocol version.

The version byte lets future hash schemes coexist with existing stored hashes.

## Future Work

- SDK support for off-chain range hash computation
- test vectors for common smart-account and solver patterns
- optional helper APIs in wallets for building PTBs around a locked range
