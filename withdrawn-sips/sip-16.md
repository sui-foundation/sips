| SIP-Number          | 16                                                                         |
| ---:                | :---                                                                       |
| Title               | Add more tx_context                                                        |
| Description         | Add tx_context to get gas sender and transaction signer of the transaction |
| Author              | Eason Chen <EasonC13>                                                      |
| Editor              | Will Riches <will@sui.io, @wriches>                                        |
| Type                | Standard                                                                   |
| Category            | Framework                                                                  |
| Created             | 2024-01-20                                                                 |
| Comments-URI        | https://sips.sui.io/comments-16                                            |
| Status              | Withdrawn                                                                  |
| Requires            | N/A                                                                        |


## Abstract

Can we get the gas sender of the transaction in Move contract?

In Move, currently, we can get the transaction sender with `tx_context::sender(ctx)`. 

Curious if we can add the feature to get the gas sender, in my case is the sponsor of a transaction, by `tx_context::gas_sender(ctx)`

Moreover, it would be great to check if the tx is signed by someone, maybe by `tx_context::is_signed_by(ctx, address)` and `tx_context::signers(ctx)`.

## Motivation

Regarding the use of `tx_context::gas_sender(ctx)`, our service includes sponsored transactions to create objects. Therefore, we aim to delete objects that have been sponsored to create by us in order to collect storage rebates and prevent individuals from abusing sponsored transactions to create objects with sponsor and then deleting them using their own addresses to get rebate from sponsor.

Regarding the use of `tx_context::is_signed_by(ctx, address)`, we plan to create transactions that require multiple signers to proceed.

## Specification

`tx_context::gas_sender(ctx)` return `address` of the gas sender.

`tx_context::is_signed_by(ctx, address)` return `boolean`.

`tx_context::signers(ctx)` return `vector<address>`.

## Rationale

When initiating a transaction, we can set signatures, gas sender and sender, but currently only the sender can be read by `tx_context`. However, we can easily read other fields.

## Backwards Compatibility

Adding a new function call to Move doesn't affect existing smart contracts.

## Copyright

[CC0 1.0](../LICENSE.md).
