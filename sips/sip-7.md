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

We describe some changes to the Pool creation process to allow for `ownable` Pools, instead of the current paradigm which always creates a shared Pool object.

## Background

Deepbook is a permissionless platform on Sui that allows building orderbooks for swapping any Pair of (`Coin`) assets. In its current implementation, when a performs a swap using the `place_market_order` (and related) functions, the remaining coins are returned; specifically, `base_asset_left` and `quote_asset_left`, while all metadata about the order matching (taker address, settlement price, number of orders filled partially or fully) are emitted as events - `OrderFilledEvent`.

While this is enough for building spot exchanges for swapping, it falls short of being sufficient for more complex financial products, like perpetual exchanges, whose functioning requires this metadata to be available on-chain. Having access to on-chain data for multiple pools in the same transaction is paramount for enabling composability of financial products.

## Motivation

```
REMOVE THIS BLOCK

This section is mandatory.

At the early stages of the SIP, this section is important in order to describe the current problem and how the SIP aims to overcome it.
```

## Specification

- Addition of the `store` ability to the `Pool` type, so that it can be owned by objects or embedded inside dynamic fields
  - `struct Pool<phantom BaseAsset, phantom QuoteAsset> has key, store { ... }`
- Allow the flexibility to create owned pools as well as shared pools
    - change the function `create_pool_` so that it returns the Pool object instead of sharing it directly
    ```move
        fun create_pool_<BaseAsset, QuoteAsset>(
            taker_fee_rate: u64,
            maker_rebate_rate: u64,
            tick_size: u64,
            lot_size: u64,
            creation_fee: Balance<SUI>,
            ctx: &mut TxContext,
        ): Pool<BaseAsset, QuoteAsset> {
        ...
        ...
        let pool = Pool<BaseAsset, QuoteAsset> {
                id: pool_uid,
                bids: critbit::new(ctx),
                asks: critbit::new(ctx),
                next_bid_order_id: MIN_BID_ORDER_ID,
                next_ask_order_id: MIN_ASK_ORDER_ID,
                usr_open_orders: table::new(ctx),
                taker_fee_rate,
                maker_rebate_rate,
                tick_size,
                lot_size,
                base_custodian: custodian::new<BaseAsset>(ctx),
                quote_custodian: custodian::new<QuoteAsset>(ctx),
                creation_fee,
                base_asset_trading_fees: balance::zero(),
                quote_asset_trading_fees: balance::zero(),
            };
            pool
        }
    ```
    - add a `public` function to create and return the Pool object that was created:
    ```move
    public fun create_pool<BaseAsset, QuoteAsset>(
        tick_size: u64,
        lot_size: u64,
        creation_fee: Coin<SUI>,
        ctx: &mut TxContext,
    ): Pool<BaseAsset, QuoteAsset> {
        assert!(coin::value(&creation_fee) == FEE_AMOUNT_FOR_CREATE_POOL, EInvalidFee);
        createpool<BaseAsset, QuoteAsset>(
            REFERENCE_TAKER_FEE_RATE,
            REFERENCE_MAKER_REBATE_RATE,
            tick_size,
            lot_size,
            coin::into_balance(creation_fee),
            ctx
        )
    }
    ```
    - add a `public entry` function `create_shared_pool` that shares the Pool after creation - this will be the current flow for pool creation
    ```move
    public entry fun create_shared_pool<BaseAsset, QuoteAsset>(
        tick_size: u64,
        lot_size: u64,
        creation_fee: Coin<SUI>,
        ctx: &mut TxContext,
    ) {
        transfer::share_object(
            create_pool<BaseAsset, QuoteAsset>(
                tick_size,
                lot_size,
                creation_fee,
                ctx
            )
        );
    }
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