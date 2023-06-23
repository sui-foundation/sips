| SIP-Number          |  |
| ---:                | :--- |
| Title               | Deepbook Composability Improvements |
| Description         | Improvements to the Deepbook package to enable better composability and modularity |
| Author              | <A list of the authors' real names or aliases, plus either their GitHub usernames (in parentheses) or email addresses (in angle brackets)> |
| Editor              |  |
| Type                | Standard |
| Category            | Framework |
| Created             | 2023-06-23 |
| Comments-URI        |  |
| Status              |  |
| Requires            | <Optional; SIP number(s), comma separated> |

## Abstract

This SIP presents improvements to the Deepbook package to enable better composability of Deepbook Pools, which would enable their use in a wide range of applications.

We describe some changes to the Pool creation process to allow for `ownable` Pools, instead of the current paradigm which always creates a shared Pool object. We also describe some modifications to the return values of some of the methods in `clob_v2` and `custodian_v2` modules for easier deepbook integration. 

## Background

Deepbook is a permissionless platform on Sui that allows building orderbooks for swapping any Pair of (`Coin`) assets. In its current implementation, when a performs a swap using the `place_market_order` (and related) functions, the remaining coins are returned; specifically, `base_asset_left` and `quote_asset_left`, while all metadata about the order matching (taker address, settlement price, number of orders filled partially or fully) are emitted as events - `OrderFilledEvent`.

While this is enough for building spot exchanges for swapping, it falls short of being sufficient for more complex financial products, like perpetual exchanges, whose functioning requires this metadata to be available on-chain.

## Motivation

```
REMOVE THIS BLOCK

This section is mandatory.

At the early stages of the SIP, this section is important in order to describe the current problem and how the SIP aims to overcome it.
```

## Specification

```
REMOVE THIS BLOCK

This section is mandatory.
```

## Rationale

```
REMOVE THIS BLOCK

This section is mandatory.

It should be used to explain how the SIP's design was arrived at, and what the pros and cons of this approach are.
```

## Backwards Compatibility

```
REMOVE THIS BLOCK

This section is mandatory, but it may simply state that there are no issues with backwards compatability.

If there are backwards incompatabilities, it should be detailed how these will addressed.
```

## Test Cases

```
REMOVE THIS BLOCK

This section is optional.

It is usually recommended to not include test cases when first submitting the SIP, and instead focus on the design and problem statement.
```

## Reference Implementation

```
REMOVE THIS BLOCK

This section is optional.

It is usually recommended to not include a reference implementation when first submitting the SIP, and instead focus on the design and problem statement.
```

## Security Considerations

```
REMOVE THIS BLOCK

This section is mandatory, but it may simply state "None" if there are no relevant considerations.
```

## Copyright

[CC0 1.0](../LICENSE.md)