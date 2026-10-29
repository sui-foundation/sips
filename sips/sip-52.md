|   SIP-Number | 52 |
|         ---: | :--- |
|        Title | `TreasuryCap` & `Supply` `destroy_zero` |
|  Description | Implement a `destroy_zero` function for both `TreasuryCap` and `Supply` |
|       Author | Kevin \<github@aftermath.finance, @admin-aftermath\>, Aftermath Finance \<[aftermath.finance](https://aftermath.finance/)\> |
|       Editor | Will Riches \<will@sui.io, @wriches\> |
|         Type | Standard |
|     Category | Framework |
|      Created | 2025-02-21 |
| Comments-URI | https://sips.sui.io/comments-6 |
|       Status | Final |
|     Requires | N/A |

## Abstract

This SIP adds a `destroy_zero` function to the `coin` and `balance` sui framework modules to allow deleting inactive `TreasuryCap`s and `Supply`s, respectively.

> As Sui will continue to evolve over time, a snapshot of the Sui repo will be used when referencing Sui Framework code. This SIP uses the latest stable version of mainnet: `mainnet-v1.42.2`.<sup>[1](https://github.com/MystenLabs/sui/tree/mainnet-v1.42.2)</sup>

## Background

**Coin.** Sui uses a unified token standard based on a single fungible type: `Coin`. The `Coin` struct is implemented as follows:<sup>[2](https://github.com/MystenLabs/sui/blob/mainnet-v1.42.2/crates/sui-framework/packages/sui-framework/sources/coin.move#L39-L43)</sup>.
```Move
/// A coin of type `T` worth `value`. Transferable and storable
public struct Coin<phantom T> has key, store {
    id: UID,
    balance: Balance<T>,
}
```

You can create a new `Coin` type by calling the `sui::coin::create_currency` function, which creates and returns the `Coin`'s `TreasuryCap` and `CoinMetadata` objects.<sup>[3](https://github.com/MystenLabs/sui/blob/mainnet-v1.42.2/crates/sui-framework/packages/sui-framework/sources/coin.move#L208-L237)</sup>

**TreasuryCap.** The `TreasuryCap` struct is utimately an object wrapper around a `Supply`. Mutable access to this object grants the ability to mint and burn new `Coin`s of the specific type. The `TreasuryCap` struct is implemented as follows:<sup>[4](https://github.com/MystenLabs/sui/blob/mainnet-v1.42.2/crates/sui-framework/packages/sui-framework/sources/coin.move#L74-L79)</sup>.
```Move
/// Capability allowing the bearer to mint and burn
/// coins of type `T`. Transferable
public struct TreasuryCap<phantom T> has key, store {
    id: UID,
    total_supply: Supply<T>,
}
```

**Balance.** The `Balance` struct is a wrapper around a `u64` that represents a store of value for a given `Coin` or `Balance` type. The `Balance` struct is implemented as follows:<sup>[5](https://github.com/MystenLabs/sui/blob/mainnet-v1.42.2/crates/sui-framework/packages/sui-framework/sources/balance.move#L29-L33)</sup>
```Move
/// Storable balance - an inner struct of a Coin type.
/// Can be used to store coins which don't need the key ability.
public struct Balance<phantom T> has store {
    value: u64,
}
```

&nbsp;&nbsp;&nbsp;&nbsp; It is often recommended to use the `Balance` struct to represent a store of value *within* another object, as opposed to its `Coin` counterpart, as the `Balance` struct removes the overhead relating to the `key` ability and is thus more efficient. To contrast, the `Coin` type should be used as a store of value within a user address. Typically, public interfaces interact with `Coin` types, while internal interfaces interact with `Balance` types.

**Supply.** The `Supply` struct has the same role as the `TreasuryCap` has for `Coin` but for `Balance`s; mutable access to a `Supply` grants the ability to mint and burn new `Balance`s of a specific type. The `Supply` struct is implemented as follows:<sup>[6](https://github.com/MystenLabs/sui/blob/mainnet-v1.42.2/crates/sui-framework/packages/sui-framework/sources/balance.move#L23-L27)</sup>
```Move
/// A Supply of T. Used for minting and burning.
/// Wrapped into a `TreasuryCap` in the `Coin` module.
public struct Supply<phantom T> has store {
    value: u64,
}
```

For completeness, one final distinction between `TreasuryCap`s and `Supply` revolves around their uniqueness. `Supply` objects can be created directly through the `create_supply` function, while `TreasuryCap`s can only be created through the `create_currency` function. `create_currency` enforces that the generic type is a one time witness, meaning there can only ever be at most one `TreasuryCap` for a given type. `create_supply` does not have the same enforcement, and thus multiple `Supply` objects can exist for a given type.

&nbsp;&nbsp;&nbsp;&nbsp; A final noteworthy fact, yet unimportant for the context of this SIP, is that all `Balance`s can be wrapped into a `Coin` type and all `Coin`s can be unwrapped into the underlying `Balance`, regardless of if the underlying value was created through the `TreasuryCap`'s `mint` function or the `Supply`'s `increase_supply` function.

## Motivation

**Position Representation.** Many on-chain verticals that facilitate the attraction (e.g., deposit) and dispersion (e.g., withdrawal) of user liquidity must have a method to distinctly represent user positions. On Sui this representation can be handled through the use of the `Coin` standard, by using a `TreasuryCap` or `Supply` to mint and burn new positions (i.e., `Coin`s); this position is colloquially known as an LP position in the context of Automated Market Makers (AMMS) but the general idea is applicable to other domains.

&nbsp;&nbsp;&nbsp;&nbsp; As such, the objects at the center of these verticals typically require wrapping a `TreasuryCap` or `Supply` within a central, domain-specific, shared object. This object then becomes the sole authority for minting and burning new positions according to domain-specific logic.

**Shared-Object Deletion.** Issues arise when this central object is no longer needed and can be deleted to free up space and reclaim the storage rebate. Both of the `TreasuryCap` and `Supply` structs do not have the `drop` ability, nor do they implement a function that allow the objects to be deleted or destroyed. Because of this, the only way to delete the wrapping shared object is to transfer the `TreasuryCap` or `Supply` elsewhere (subject to their respective abilities). For example, sending these objects to the null address (`0x0`) is an obvious choice to assert they are never interactive with again, effectively making them inaccessible akin to a deletion.

However, this is unpreferable for a miriad of reasons:
 1. It is non-intuitive,
 1. Requires you to add bloat to your module handle the wrapping of a `Supply` object within a locally-defined object that has the `key` ability first.
 1. The object will forever be inaccessible--which was desired--but will still take up space in storage, even though it is no longer needed.

&nbsp;&nbsp;&nbsp;&nbsp; For `TreasuryCap`s, you have the option to call `public_freeze`, akin to an immutable sharing of the object, which will allow you to transfer the `TreasuryCap` in order to avoid the implicit drop and delete the wrapping shared object. However, this is not an option for `Supply` objects as `Supply` does not have the `key` ability. Deletion-through-`public_freeze` still suffers from (1) and (3).

A more straightforward approach would be to extend the interface of the `TreasuryCap` and `Supply` structs to include a `destroy_zero` function to allow deleting these types and reclaiming their storage rebate.

## Prerequisites

There are no prerequisites for this SIP.

## Specification

A `destroy_zero_<object>` function will be added to both the `coin` and `balance` modules to allow the deletion of `TreasuryCap` and `Supply` objects that have a total supply of zero. Function aliases will also be added to allow calling these functions with the name `destroy_zero` which is currently being reserved by the `destroy_zero` variants for deleting `Coin`s and `Balance`s.

## Rationale

With respective `destroy_zero` functions, objects that wrap `TreasuryCap` or `Supply` objects for their entire lifecycle can be properly deleted at the end of the lifecycle.

## Backwards Compatibility

This SIP presents no issues with backwards compatibility.

## Reference Implementation

### i. Changes to `sui::coin`

```Move
public use fun destroy_zero_treasury_cap as TreasuryCap.destroy_zero;
/// Destroy a TreasuryCap with a total supply of zero
public fun destroy_zero_treasury_cap<T>(treasury_cap: TreasuryCap<T>) {
    treasury_cap.treasury_into_supply()
        .destroy_zero();
}
```

### ii. Changes to `sui::balance`

```Move
public use fun destroy_zero_supply as Supply.destroy_zero;
/// Destroy a `Supply` with a total value of zero.
public fun destroy_zero_supply<T>(supply: Supply<T>) {
    assert!(supply.value == 0, ENonZero);

    let Supply { value: _ } = supply;
}
```

## Security Considerations

The only security concern worth mentioning is destroying `TreasuryCap` or `Supply` objects that are still active. This would prevent the deletion of already minted `Coin` or `Balance` objects and thus could result in a permanent loss of value for token holders; e.g., in the LP scenario described above the LP `Coin` must be burned during the withdrawal process. As such, the reference implementation enforces that the `TreasuryCap` or `Supply` objects are inactive (i.e., their total supply is zero) before deletion.

## References

1. [[Sui Repo] mainnet-v1.42.2](https://github.com/MystenLabs/sui/tree/mainnet-v1.42.2)
2. [[Sui Repo] `Coin`](https://github.com/MystenLabs/sui/blob/mainnet-v1.42.2/crates/sui-framework/packages/sui-framework/sources/coin.move#L39-L43)
3. [[Sui Repo] `create_currency`](https://github.com/MystenLabs/sui/blob/mainnet-v1.42.2/crates/sui-framework/packages/sui-framework/sources/coin.move#L208-L237)
4. [[Sui Repo] `TreasuryCap`](https://github.com/MystenLabs/sui/blob/mainnet-v1.42.2/crates/sui-framework/packages/sui-framework/sources/coin.move#L74-L79)
5. [[Sui Repo] `Balance`](https://github.com/MystenLabs/sui/blob/mainnet-v1.42.2/crates/sui-framework/packages/sui-framework/sources/balance.move#L29-L33)
6. [[Sui Repo] `Supply`](https://github.com/MystenLabs/sui/blob/mainnet-v1.42.2/crates/sui-framework/packages/sui-framework/sources/balance.move#L23-L27)

## Copyright

[CC0 1.0](../LICENSE.md).
