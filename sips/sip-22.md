|   SIP-Number | 22                                                       |
| -----------: | :------------------------------------------------------- |
|        Title | Coin Metadata V2                                         |
|  Description | New management and authorization system for CoinMetadata |
|       Author | @damirka                                                 |
|       Editor | Will Riches <will@sui.io, @wriches>                      |
|         Type | Standard                                                 |
|     Category | Framework                                                |
|      Created | 2024-04-20                                               |
| Comments-URI | https://sips.sui.io/comments-22                          |
|       Status | Draft                                                    |
|     Requires | -                                                        |

## Abstract

This proposal introduces a new system for creating and managing metadata for currencies on Sui. The system separates the metadata management from the `TreasuryCap` allowing for more flexibility in currency management. Additionally, it introduces a new system object `CoinMetadataRegistry` which serves as a single discovery point for metadatas, and allows registering metadata for currencies created via the low-level `balance::*` API.

## Glossary

- `Coin` - object defined in the `sui::coin` module which represents a single currency value in the Sui blockchain.
- `CoinMetadata` - object defined in the `sui::coin` module which contains information about the currency, such as its name, symbol, icon, url and decimals. Can only be updated with the `TreasuryCap` and created via the `coin::create_currency` function.
- `TreasuryCap` - object defined in the `sui::coin` module which manages the minting and burning of the currency, as well authorizes the changes to the `CoinMetadata` object.
- `Supply` - lower-level struct defined in the `sui::balance` module which represents the total supply of a currency (wrapped into the `TreasuryCap` object).
- `Balance` - lower-level struct defined in the `sui::balance` module which represents the balance of a user (wrapped into the `Coin` object).

## Motivation

Currently, there are several well-known issues related to `Coin` in general and `CoinMetadata` in particular:

1. `TreasuryCap` is an overpowered capability which manages both the supply (essential property of the currency) and the metadata (secondary property). This makes it difficult to implement certain scenarios, such as "freezing" (locking) the `TreasuryCap` to prevent new tokens from being minted or burned, while maintaining the ability to update the `CoinMetadata`.

2. The `CoinMetadata` only works for currencies created via the `coin::create_currency` function. This limitation reduces flexibility of custom currencies created via a lower-level `Balance` and `Supply` API, they simply cannot have `CoinMetadata` associated with them.

3. There is no standard way of handling and storing the `CoinMetadata`, which results in a more complex discovery process. And may potentially lead to irreversible issues in the future.

The three issues outlined above are the main reasons for proposing a new standard for storing and managing the metadata. While this proposal could have been submitted before, the most recent and the upcoming improvements in Sui make it possible to implement it in a more efficient way.

## Specification

For clarity, we have split this section into multiple parts: the core addition, the migration and potential issues that may arise.

## Core Addition

The centrepiece of this proposal is the introduction of a new system object `CoinMetadataRegistry` which would store metadatas and provide a way to access and manage them. The object is expected to have a stable, reserved address which would be preserved across environments.

When the metadata is registered by the authority (in case of Coin - the `TreasuryCap`, in case of Balance - `Supply`), a new `CoinMetadataCap` capability would be created. This capability will allow updating the stored metadata with an option to freeze it, preventing further updates.

The stored metadata will differ from the current `CoinMetadata` type, as it will have additional fields indicating whether the metadata is mutable or frozen, and the link to the `TreasuryCap` if it exists / known.

Single source of truth for the metadata will simplify the discovery, as well as guarantee the uniqueness of the metadata. One of the reasons why the `CoinMetadata` was limited to Treasury-authorized currencies was the lack of this property.

## Migration

The migration and adoption of the new system would be gradual and would require extra effort from the developers. For better visibility, we have split the migration into three scenarios:

1. New Currencies - how to register a metadata for a new currency.
2. Existing Mutable Metadata - how to migrate the existing mutable metadata.
3. Existing Frozen Metadata - how to migrate the existing frozen metadata.
4. Supply-based currencies - how to register a metadata for a currency created via the `balance::*` API.

### New Currencies / Owned Metadata

When creating a new currency, the `CoinMetadata` object can be passed to the `CoinMetadataRegistry` directly along with the `TreasuryCap`. This is the easiest scenario, with the only complication being the inability to perform this registration in the module `init` function (more on this below).

For illustration purposes (here and below), we provide an example signature:

```move
/// Register an owned or shared metadata object.
public fun register_metadata<T>(
   reg: &mut CoinMetadataRegistry,
   treasury_cap: &TreasuryCap<T>,
   metadata: CoinMetadata<T> // takes by value!
): CoinMetadataCap<T>;
```

### Existing Shared Metadata

With the introduction of shared object deletion, it is now possible to consume a shared object. This feature can be used to migrate the existing shared `CoinMetadata` to the `CoinMetadataRegistry`. The registering party will have to present the `TreasuryCap` to receive the `CoinMetadataCap` capability.

> The function presented in [the section above](#new-currencies--owned-metadata) can be reused for this scenario.

### Existing Frozen Metadata

The trickiest scenario is migrating the existing frozen metadata. Frozen objects cannot be consumed, hence they will persist in this state forever. However, to enable the migration, the `CoinMetadata` object can be copied to the `CoinMetadataRegistry`. A copied version will be frozen unless the `TreasuryCap` is presented to receive the `CoinMetadataCap` capability. Then, the copied metadata can be updated as usual or frozen again.

```move
/// Copies the metadata object to the registry.
public fun copy_metadata<T>(
   reg: &mut CoinMetadataRegistry,
   metadata: &CoinMetadata<T>
);
```

Because it is impossible to check the ownership of the `CoinMetadata` object, the `copy_metadata` function can be called on any metadata. However, the `CoinMetadataCap` capability will only be returned if the `TreasuryCap` is presented:

```move
/// Claim the `CoinMetadataCap` object by presenting the `TreasuryCap`.
public fun claim_metadata_cap<T>(
   reg: &mut CoinMetadataRegistry,
   treasury_cap: &TreasuryCap<T>,
): CoinMetadataCap<T>;
```

The claim operation can only be performed once.

### Supply-based currencies

To allow metadata registration for currencies created via the `balance::*` API, the `Supply` object will be extended with the `CoinMetadataCap` capability. The `Supply` object will be able to register the metadata in the `CoinMetadataRegistry` and update it as needed.

```move
/// Register a metadata object for the supply-based currency.
public fun register_with_supply<T>(
   reg: &mut CoinMetadataRegistry,
   supply: Supply<T>,
   decimals: u8,
   name: String,
   // ...
): (Supply<T>, CoinMetadataCap<T>);
```

To prevent the misuse of the `TreasuryCap` for the supply-based currencies, the function requres the `Supply` to be passed _by value_. This way, this function can never be called by the `TreasuryCap` (requires destroying the `TreasuryCap` first).

## Potential Issues

TBD

## Rationale

TBD


## Backwards Compatibility

The new system builds on top of the existing implementation and adds new functionality. However, because it expects the future instances of the `CoinMetadata` to be stored in the Registry, some of the existing applications which take ownership of the `CoinMetadata` (such as bridges) won't be able to adopt the new system without changes.

The new approach does not discard the existing system, so the existing currencies will continue to work as before. The new system is expected to be adopted gradually, as the new currencies are created.

## Test Cases

---

## Reference Implementation

The reference implementation is available in the [MystenLabs/sui](https://github.com/MystenLabs/sui/pull/17381) repository, submitted as a draft PR.

## Security Considerations

TBD

## Copyright

-
