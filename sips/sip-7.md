| SIP-Number          |  |
| ---:                | :--- |
| Title               | Improving Deepbook Composability |
| Description         | A change to the Pool struct to have the `store` abilty, and some related function changes to improve re-usability of Deepbook as a use-case specific matching engine for protocols |
| Author              | Kinshuk ([kinshukk](https://github.com/kinshukk)), Sarthak ([Rajwanshi1](https://github.com/Rajwanshi1)), Aditya ([adityadw1998](https://github.com/adityadw1998)), Ananya ([avantgardenar](https://github.com/avantgardenar)) |
| Editor              |  |
| Type                | Standard |
| Category            | Framework |
| Created             | 2023-06-23 |
| Comments-URI        |  |
| Status              |  |
| Requires            |  |

## Abstract

This SIP presents improvements to the Deepbook package on Sui. We propose a change to the Pool struct to have the `store` ability, and return the object instance from the public `create_pool` function instead of the current paradigm which always creates a shared Pool object. 
This would enable easier creation of private pools helping protocols use Deepbook as a white-labeled matching engine in their stack. The current way of creating all pools public (ie shared objects) by default prevents fragmentation, but we believe liquidity for major pairs will naturally aggregate via market behaviour. At the same time, allowing private pools opens up many new use-cases of Deepbook as a public good. Saves lots of development and audit time for the protocols building on top, they get to focus on their core strengths like margining / liquidations etc. while not worrying about order intent matching and trade settlement.

## Background

Deepbook is a shared decentralized central limit order book (CLOB) built for the Sui ecosystem. A pool on deepbook is an orderbook instance of a particular trading pair. Anyone can deploy pools for swapping any pair of (`Coin<T>`) assets. Pools can be created permissionlessly with the `key` ability, which provides them a unique object ID & makes it independently indexable by the nodes.

While this is enough for building a simple spot exchange, it falls short of providing flexibility to build more complex financial products. It limits the re-usability of the order-matching module because protocols that have something to do with leverage or lending usually want to keep isolated infrastructures so they can manage the total risk of their system better as well as enforce liquidations, but Deepbook pools are all public shared by default. It could be better to have it as a configuration set by the pool creator, enabling both use-case specific private orderbooks and public shared orderbooks for common asset pairs.

## Motivation

We're building a cross-margined perpetuals trading DEX on top of Deepbook, functioning of which requires wrapping the `Pool<Coin<X>, Coin<Y>>` under another shared object (as dynamic fields) to obtain a collection of pools & store application specific metadata on top of Deepbook pools. Having access to on-chain data for multiple pools in the same transaction is key here, since cross margining enables users to use profits in one market to fund losses in another market. 

At a broader sense, via account caps there is a way for protocols to get custody of user orders and build on top of the matching engine, however, adding these changes are neccessary to make the matching engine customisable as per relevant use cases. We believe many similar protocols dealing with undercollateralized assets might need this level of control. Any smart contract that has logic needing data from multiple pools dynamically(in a single transaction) cannot be implemented right now. For us, the need for owned pools originated from the need to dynamically query pool data in the margin related smart contract, for some protocol, it might be to enforce cross-market liquidations. 

## Specification

- Addition of the `store` ability to the `Pool` type, so that it can be wrapped under other objects or be stored as dynamic fields.
  - `struct Pool<phantom BaseAsset, phantom QuoteAsset> has key, store { ... }`
- Allow the flexibility to create owned pools as well as shared pools
    - change the function `create_pool_` so that it returns the Pool object instead of sharing it directly
    ```Rust
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
    - change `public` function to create and return the Pool object that was created, instead of transfering it as a shared object:
    ```Rust
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
    - add a `public entry` function `create_shared_pool` that shares the Pool after creation - this will enable clients to safely create pools & ensure the pool is publicly shared without relying on the PTB to share it publicly.
    ```Rust
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

This flexibility to create owned pools with the `store` ability would allow a `Pool` object to be embedded inside dynamic fields. This would enable efficient computation over a variable number of pools in a single transaction. 

For example, if a dApp needs to implement logic that requires getting and modifying the state of multiple pools in a single `function`, it can wrap `Pool1`, `Pool2`, ... inside a Dynamic Table and then iterate over the table to perform the required computation. 

Contrasting this with the current situation, the same dApp would need to implement different functions to process variable number of Pools. If there are 2 Pools, the relevant function would look as follows:
`public fun process_pools_2(pool1: Pool, pool2: Pool, ...) { ... }`

Now, if the same dApp adds another Pool, it would need to implement a new function:
`public fun process_pools_3(pool1: Pool, pool2: Pool, pool3: Pool, ...) { ... }`

This is because we cannot pass `vector<Pool>` into a function from a PTB.

With the suggested upgrades, one can create a higher-level object `PoolInfo` which would have a `TableVec<Pool>` as one of its fields. This would allow the dApp to implement a single function `process_pools` that can process any number of pools by passing this `PoolInfo` object as an argument.

## Backwards Compatibility

Once the deepbookV2 package goes live with `Pool<Coin<X>, Coin<Y>>` with just the `key` ability, it would not be back-compatible for adding a store ability to the same pools, a migration would be neccessary. We think making this change before the release might be better, or we can think of a separate package specifically meant to create custom orderbooks and the current one specifically for creating shared public liquidity pools.

## Security Considerations

Returning the pool from the public create pool function would lead to a risk of undesired ownership assignment since it will return the pool, & PTB would be responsible to assign the correct ownership. For this reason, we should introduce a `public entry function create_shared_pool()` which will ensure all of it's clients that the Pool is created with the shared object ownership. 

## Copyright

[CC0 1.0](../LICENSE.md)
