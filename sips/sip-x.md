|   SIP-Number | <Leave this blank; it will be assigned by a SIP Editor>  |
| -----------: | :------------------------------------------------------- |
|        Title | Coin Metadata V2                                         |
|  Description | New management and authorization system for CoinMetadata |
|       Author | @damirka                                                 |
|       Editor | <Leave this blank; it will be assigned by a SIP Editor>  |
|         Type | Standard                                                 |
|     Category | Framework                                                |
|      Created | 2024-04-20                                               |
| Comments-URI | <Leave this blank; it will be assigned by a SIP Editor>  |
|       Status | <Leave this blank; it will be assigned by a SIP Editor>  |
|     Requires | -                                                        |

## Abstract

This proposal introduces a new approach to managing the `CoinMetadata` object. The new system reduces the centralization of authority by separating the `TreasuryCap` and `CoinMetadataCap` objects, allowing for more flexibility in managing the Coin's metadata. Additionally, it suggests a new system object `CoinMetadataRegistry` which would store the `CoinMetadata` objects and provide a single way to discover, access and manage them.

## Glossary

- `Coin` - object defined in the `sui::coin` module which represents a currency in the Sui blockchain.
- `CoinMetadata` - object defined in the `sui::coin` module which contains information about the currency, such as its name, symbol, icon, url and decimals.
- `TreasuryCap` - object defined in the `sui::coin` module which manages the minting and burning of the currency, as well authorizes the changes to the `CoinMetadata` object.
- `Supply` - lower-level struct defined in the `sui::balance` module which represents the total supply of a currency (wrapped into the `TreasuryCap` object).
- `Balance` - lower-level struct defined in the `sui::balance` module which represents the balance of a user (wrapped into the `Coin` object).

## Motivation

Currently, there are several well-known issues related to `Coin` in general and `CoinMetadata` in particular:

1. `TreasuryCap` serves too many purposes: it manages both minting and burning, and the `CoinMetadata` authorization. This centralization of authority makes it difficult to implement certain scenarios, such as freezing the `TreasuryCap` to prevent new tokens from being minted or burned, while maintaining the ability to update the `CoinMetadata`.
2. The `CoinMetadata` only works for currencies created via the `coin::create_currency` function. This limitation reduces flexibility of custom currencies created via a lower-level `Balance` and `Supply` API, they simply cannot have `CoinMetadata` associated with them.
3. Today, there is no standard way of handling and storing the `CoinMetadata`. Some guides suggest _freezing_ it right after creation, some suggest sending it to `0x0`, and some suggest keeping it _shared_. The lack of consistency in handling the `CoinMetadata` can lead to potential issues in the future as well as complicating object discovery.

The three issues outlined above are the main reasons for proposing a new standard for storing and managing the `CoinMetadata` object. While this proposal could have been submitted befor, the recent and upcoming improvements in Sui make it possible to implement it in a more efficient way.

## Specification

To address the issues outlined in the motivation, we propose the following changes:

1. Create a special system object `CoinMetadataRegistry` which would store the `CoinMetadata` objects and provide a way to access and manage them. The object is expected to have a stable, reserved address which would be preserved across environments.
2. Introduce a new capability `CoinMetadataCap` which can be used to mutate the `CoinMetadata` object. This capability would be separate from the `TreasuryCap` and would only allow updating the `CoinMetadata`.
3. Store additional information about the `CoinMetadata` object in the `CoinMetadataRegistry` object. This information would explicitly state whether the `CoinMetadata` is mutable or frozen, and would also include the "source" of it - whether it comes from a `coin::create_currency` call or from a lower-level `balance::*` one.

While this proposal has a very ambitious goal, it is possible to omit some of the features in the initial implementation and add them later. However, it is stil important to have a clear vision of the final goal, so that the initial implementation is not in conflict with it.

<!-- *The ID of the Registry object could be 0xC015 (to be similar to "COIN" in hexspeak)*. -->

The proposed changes are split into multiple parts for clarity:

### CoinMetadataRegistry

> This section contains code samples, see the [Reference Implementation](#reference-implementation) section for the full sample.

1. A new `CoinMetadataRegistry` object should be added to the Sui Framework (module not decided yet).
2. The Registry would store `CoinMetadata` objects along with additional information as typed dynamic fields.
3. The Registry would have a stable address which would be preserved across environments.
4. The Registry would accept `CoinMetadata` sent to it via the _Transfer to Object_ (TTO) feature.
5. The Registry would provide access to the `CoinMetadata` objects via the `CoinMetadataCap` capability.

### CoinMetadataCap

> This section contains code samples, see the [Reference Implementation](#reference-implementation) section for the full sample.

1. A new `CoinMetadataCap` object should be added to the `sui::coin` module.
    ```move
    public struct CoinMetadataCap<phantom T> has key, store { /* ... */ }
    ```
2. The `CoinMetadataCap` can be created from the `TreasuryCap`, adding a marker to the TCap, making duplicate claims impossible.
3. New methods gated by the `CoinMetadataCap` should be added to the `sui::coin` module:
    - `update_name`
    - `update_symbol`
    - `update_icon_url`
    - `update_description`
4. Current methods for updating the `CoinMetadata` gated by the `TreasuryCap` should check if there is a `CoinMetadataCap` object and if it is present, abort with an error code. See the [Reference Implementation](#reference-implementation) for the code sample.

## Rationale

```
It should be used to explain how the SIP's design was arrived at, and what the pros and cons of this approach are.
```

The `Balance` and `Coin` were designed long before mainnet launch and have been rather stable since then. The decisions made back then were based on the best practices of the time, but the system has evolved, and we have observed some limitations and issues with the current design.

With the planned launch of Mysticeti and the significant decrease in the shared object latency, it will be possible to implement a very efficient registry in a more centralized fashion. Additionally, the _Transfer to Object_ (TTO) feature mitigates certain limitations in the current design of module initializer (see [Reference Implementation](#reference-implementation)) and allows sending the `CoinMetadata` object to the registry directly during the package publishing.

## Backwards Compatibility

The new system builds on top of the existing implementation and adds new functionality. However, because it expects the future instances of the `CoinMetadata` to be stored in the Registry, some of the existing applications which take ownership of the `CoinMetadata` won't be able to adopt the new system without changes.

Indexers and other applications which discover, store and provide information about the `CoinMetadata` would need to be updated to support the new system. However, the proposed change would significantly simplify the process, and we expect the change to be quite well-received.

## Test Cases

---

## Reference Implementation

---

## Security Considerations

None (TBD)

## Copyright

-
