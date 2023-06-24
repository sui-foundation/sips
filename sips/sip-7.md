| SIP-Number          |  |
| ---:                | :--- |
| Title               | Deepbook Composability Improvements |
| Description         | Improvements to the Deepbook package to enable better composability and modularity |
| Author              | Kinshuk ([kinshukk](https://github.com/kinshukk)), Sarthak ([Rajwanshi1](https://github.com/Rajwanshi1)), Aditya ([adityadw1998](https://github.com/adityadw1998)), Ananya ([avantgardenar](https://github.com/avantgardenar)) |
| Editor              |  |
| Type                | Standard |
| Category            | Framework |
| Created             | 2023-06-23 |
| Comments-URI        |  |
| Status              |  |
| Requires            |  |

## Abstract

This SIP presents improvements to the Deepbook package to enable better composability of Deepbook Pools, which would open up multiple usecases which will enable Deepbook to be used as a matching engine.

We propose a change to the Pool struct to have the `store` abilty, and return the object instance from public `create_pool` function instead of the current paradigm which always creates a shared Pool object.

## Background

Deepbook is a permissionless platform on Sui that allows building pools for swapping any pair of (`Coin<T>`) assets. Pools can be created permionlessly with the `key` ability, which provides them a unique object ID & makes it independently indexable by the nodes.

While this is enough for building a simple spot exchange, it falls short of providing flexibility to build more complex financial products, like cross-margined perpetual DEX, whose functioning requires wrapping the `Pool<Coin<X>, Coin<Y>>` under another shared object to obtain a collection of pools & store application specific metadata on top of deepbook pools. Having access to on-chain data for multiple pools in the same transaction is paramount for enabling composability & more complex use cases where deepbook can be used as a matching engine in general.

## Motivation

TODO

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

This flexibility to create owned pools with the `store` ability would allow a `Pool` object to be embedded inside dynamic fields. This would enable efficient computation over a variable number of pools. 

For example, if a dApp needs to implement logic that requires getting and modifying the state of multiple pools in a single `function`, it can wrap `Pool1`, `Pool2`, ... inside a Dynamic Table and then iterate over the table to perform the required computation. 

Contrasting this with the current situation, the same dApp would need to implement different functions to process variable number of Pools. If there are 2 Pools, the relevant function would look as follows:
`public fun process_pools_2(pool1: Pool, pool2: Pool, ...) { ... }`

Now, if the same dApp adds another Pool, it would need to implement a new function:
`public fun process_pools_3(pool1: Pool, pool2: Pool, pool3: Pool, ...) { ... }`

This is because we cannot pass `vector<Pool>` into a function from a PTB.

With the suggested upgrades, one can create a higher-level object `PoolInfo` which would have a `TableVec<Pool>` as one of its fields. This would allow the dApp to implement a single function `process_pools` that can process any number of pools by passing this `PoolInfo` object as an argument.

## Backwards Compatibility
TODO: 
This section is mandatory, but it may simply state that there are no issues with backwards compatability.

If there are backwards incompatabilities, it should be detailed how these will addressed.

## Security Considerations

TODO:
This section is mandatory, but it may simply state "None" if there are no relevant considerations.

## Copyright

[CC0 1.0](../LICENSE.md)
