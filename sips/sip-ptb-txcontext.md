| SIP-Number          | <Leave this blank; it will be assigned by a SIP Editor> |
| ---:                | :--- |
| Title               | Expose ProgrammableTransaction data in TxContext |
| Description         | Accessing MoveCalls (packages, modules, function names, type arguments and arguments) of the executed PTB on-chain |
| Author              | Thouny <thouny@tuta.io, @thounyy> |
| Editor              | <Leave this blank; it will be assigned by a SIP Editor> |
| Type                | Standard |
| Category            | Framework |
| Created             | 2024-07-30 |
| Comments-URI        | <Leave this blank; it will be assigned by a SIP Editor> |
| Status              | <Leave this blank; it will be assigned by a SIP Editor> |

## Abstract

This SIP proposes to enrich the TxContext struct defined in the Sui Framework with additional data related to the Programmable Transaction Block (PTB) that instantiates it.

## Motivation

Currently, there is no way to have access to the global context of the on-going transaction, except for the sender, epoch, created ids and digest. One cannot verify, within a Move package, which functions are called and which objects are used. The transaction digest is a hash of all inputs including the gas object, therefore preventing objects used as arguments to be verified against it with an arbitrary gas object.

We are building [Kraken](https://github.com/gmove-io/kraken), a smart contract based multisig, and we need users to be able to submit arbitrary transactions for approval before execution. The flow would be as follows:

1. A user proposes a set of commands & inputs composing the PTB he wants to see executed.
2. Members can verify the transaction by reviewing the submitted data, and approve it.
3. Once approved, the transaction is executed on-chain and its commands & inputs are checked against the proposed ones.

## Specification

The finality is to modify `TxContext` in Move to include the packages, modules and functions of the move calls, together with the associated type arguments and arguments, based on the [ProgrammableMoveCall](https://github.com/MystenLabs/sui/blob/33c65ab633d3dee3144bb7d2a3450835d406a348/crates/sui-types/src/transaction.rs#L697) that is constructed upon execution.

``` rust 
/// optional as objects ids could be passed as string as well
public enum Arg has store, drop {
    /// A Sui object
    Object(ID),
    /// A Move pure type
    Pure(String),
}

public struct MoveCall has store, drop {
    /// The package containing the module and function.
    package_id: ID,
    /// The specific module in the package containing the function.
    module_name: String,
    /// The function to be called.
    function_name: String,
    /// The type arguments to the function.
    type_arguments: vector<TypeName>,
    /// The arguments to the function.
    arguments: vector<Arg>, // could also be vector<String>
}

/// modified TxContext
public struct TxContext has drop {
    /// The address of the user that signed the current transaction
    sender: address,
    /// Hash of the current transaction
    tx_hash: vector<u8>,
    /// The current epoch number
    epoch: u64,
    /// Timestamp that the epoch started at
    epoch_timestamp_ms: u64,
    /// Counter recording the number of fresh id's created while executing
    /// this transaction. Always 0 at the start of a transaction
    ids_created: u64,
    /// Move calls from the PTB
    move_calls: vector<MoveCall>,
}
```

During transaction execution, TxContext is constructed within [execute_transaction_to_effects](https://github.com/MystenLabs/sui/blob/5056e4f192f6b57f2ed507a6a292a0d85c66a47b/sui-execution/latest/sui-adapter/src/execution_engine.rs#L80). `transaction_kind` could be passed to [the TxContext constructor](https://github.com/MystenLabs/sui/blob/5056e4f192f6b57f2ed507a6a292a0d85c66a47b/sui-execution/latest/sui-adapter/src/execution_engine.rs#L125) to fill the missing data using [ProgrammableTransaction](https://github.com/MystenLabs/sui/blob/33c65ab633d3dee3144bb7d2a3450835d406a348/crates/sui-types/src/transaction.rs#L637).

I don't have a strong understanding of the Sui codebase so I might miss some key elements or even point at the wrong place.

## Rationale

### How to expose the ProgrammableTransaction data

[ProgrammableTransaction](https://github.com/MystenLabs/sui/blob/33c65ab633d3dee3144bb7d2a3450835d406a348/crates/sui-types/src/transaction.rs#L637) is composed of a vector of commands (MoveCall, TransferObject, Publish, etc.) and a vector of inputs. Using only the MoveCall commands would be sufficient on-chain and would simplify the implementation.

Each MoveCall has an associated [data struct](https://github.com/MystenLabs/sui/blob/33c65ab633d3dee3144bb7d2a3450835d406a348/crates/sui-types/src/transaction.rs#L697) that contains the package, module, function name, type arguments and arguments indexes. Since it only provides the indexes of the arguments we also need to pass the inputs vector to get the pure and object arguments.

**The question is how these MoveCall Commands and Inputs should be defined in Move?**

- should the pure and object arguments be differentiated, or everything can be passed as a `String` or `vector<u8>`?
- how to associate each MoveCall with its corresponding arguments?
- should it define new structs or use bcs de(serialization) and therefore have a single `vector<u8>`?
- should it provide only MoveCall commands or more?

### How to handle "Results" Inputs

The other complexity resides in the fact that some of the Inputs are the Results of previous commands. A placeholder like a Result type or None could be used. Additionally, the `ids_created` field could be used if needed. 

## Backwards Compatibility

I don't see any issue regarding backwards compatibility.

## Security Considerations

The only thing to consider from my perspective is the possibility to game transactions that use randomness. And the data should remain read-only.
