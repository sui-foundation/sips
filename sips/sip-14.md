|   SIP-Number | 14                                                                                                                                                   |
| -----------: | :--------------------------------------------------------------------------------------------------------------------------------------------------- |
|        Title | New struct MatchedOrderMetadata in deepbook.                                                                                                         |
|  Description | Implementing new struct MatchedOrderMetadata to the sui-framework package deepbook, to return matched order metadata from new place order functions. |
|       Author | Sarthak <@Rajwanshi1>                                                                                                                                |
|       Editor |                                                                                                                                                      |
|         Type | Standard                                                                                                                                             |
|     Category | Framework                                                                                                                                            |
|      Created | 2023-12-02                                                                                                                                           |
| Comments-URI |                                                                                                                                                      |
|       Status | Draft                                                                                                                                                |
|     Requires | N/A                                                                                                                                                  |

## Abstract

This SIP specifies implementing & returning new struct MatchedOrderMetadata<BaseAsset, QuoteAsset> into sui-framework's package deepbook. Existing place order functions do not return information about orders matched(price, size & parties involved in trade) on-chain & only emit this info as events.

This SIP adds new functions & struct which returns order matched metadata from place order functions, which can enable many use cases for protocols built on top of deepbook.

## Motivation

Protocols using deepbook as matching engine & base liquidity layer for DeFi applications have no way to impose additional checks & asserts on top of deepbook's checks on order matching. Knowing counterparty on chain is important use case for both spot and perp (enables instant p2p settlement). Hence, returning this information provides a hook that enables protocols to put checks on trade settlement based on their use cases on top of matched orders returned from deepbook in the same txn with no changes in deepbook.

Here are a few generic use cases which can be simplifield.

1. Spot-trading: Currently deepbook doesn't support slippage/min_buy_amount checks natively. Protocols like KriyaDEX(pro-trading) which offers spot trading UI on deepbook, can easily put slippage checks which is essential for users to to not incur un-neccasary losses due to high slippage in low liquidity & high spreads environments.
2. Leverage trading: All protocols building leverage trading protocols on deepbook would essentialy need some additional checks on the price at which orders are matched on deepbook to safely deal with leverage & not incur losses due to price manipulation(more details in security section). Instant p2p settlement is also essential for margin protocols to ensure every leveraged profit equals someone's leveraged loss.
3. Third party integratopions: using deepbook as liquidity layer, can add additional asserts & policies on matched orders in same txn(revert if matched orders doesn't fullfill custom policies & checks). This approach provides a generic hook for protocols to add additional asserts over matched orders & counter parties involved in their respective packages with no changes in deepbook.

## Security 

Proper checks on order matching is crucial for all protocols to ensure no exploits using price manipulation of deepbook.

Once such possible attack in context of perps protocols:

-   Attacker configures 2 wallets (w1/w2) in BTC market.
-   w1 places 10x short order at a very low price (say $100/BTC).
-   w2 places 10x long order to match with w1 in the same PTB.
-   After order matching, w2 is instantly at a high profit(mark price being $35k for BTC) while w1 is in a huge loss & banckrupt.
-   w2 waits until there is some liquidity in deepbook & closes it's position with someone else while realising the profits & withdraws.
-   w1 is instantly bankrupt with a loss to insurance fund.
-   This induces bad debt to the system & margin protocol's insurance fund can be drained.

### How returning matched orders prevents this attack?

Third party margin protocols can enforce checks on the matched orders price. If matched order price is deviated by say x%, txns can be reverted which will prevent order matching at highly deviated price(wrt mark_price) in low liquidity environments. This scenario is analogous to slippage in spot deepbook pools.

## Specification

PR: (https://github.com/MystenLabs/sui/pull/15119)

New struct in clob_v2.move:

```Rust
 /// Returned as metadata only when a maker order is filled from place order functions.
    struct MatchedOrderMetadata<phantom BaseAsset, phantom QuoteAsset> has copy, store, drop {
        /// object ID of the pool the order was placed on
        pool_id: ID,
        /// ID of the order within the pool
        order_id: u64,
        /// Direction of order.
        is_bid: bool,
        /// owner ID of the `AccountCap` that filled the order
        taker_address: address,
        /// owner ID of the `AccountCap` that placed the order
        maker_address: address,
        /// qty of base asset filled.
        base_asset_quantity_filled: u64,
        /// price at which base asset filled.
        price: u64,
        taker_commission: u64,
        maker_rebates: u64
    }
```

New functions signatures in clob_v2.move

```Rust
 public fun swap_exact_base_for_quote_with_metadata<BaseAsset, QuoteAsset>(
        pool: &mut Pool<BaseAsset, QuoteAsset>,
        client_order_id: u64,
        account_cap: &AccountCap,
        quantity: u64,
        base_coin: Coin<BaseAsset>,
        quote_coin: Coin<QuoteAsset>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (Coin<BaseAsset>, Coin<QuoteAsset>, u64, vector<MatchedOrderMetadata<BaseAsset, QuoteAsset>>)

public fun swap_exact_quote_for_base_with_metadata<BaseAsset, QuoteAsset>(
        pool: &mut Pool<BaseAsset, QuoteAsset>,
        client_order_id: u64,
        account_cap: &AccountCap,
        quantity: u64,
        clock: &Clock,
        quote_coin: Coin<QuoteAsset>,
        ctx: &mut TxContext,
    ): (Coin<BaseAsset>, Coin<QuoteAsset>, u64, vector<MatchedOrderMetadata<BaseAsset, QuoteAsset>>)

public fun place_market_order_with_metadata<BaseAsset, QuoteAsset>(
        pool: &mut Pool<BaseAsset, QuoteAsset>,
        account_cap: &AccountCap,
        client_order_id: u64,
        quantity: u64,
        is_bid: bool,
        base_coin: Coin<BaseAsset>,
        quote_coin: Coin<QuoteAsset>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (Coin<BaseAsset>, Coin<QuoteAsset>, vector<MatchedOrderMetadata<BaseAsset, QuoteAsset>>)

 public fun place_limit_order_with_metadata<BaseAsset, QuoteAsset>(
        pool: &mut Pool<BaseAsset, QuoteAsset>,
        client_order_id: u64,
        price: u64,
        quantity: u64,
        self_matching_prevention: u8,
        is_bid: bool,
        expire_timestamp: u64, // Expiration timestamp in ms in absolute value inclusive.
        restriction: u8,
        clock: &Clock,
        account_cap: &AccountCap,
        ctx: &mut TxContext
    ): (u64, u64, bool, u64, vector<MatchedOrderMetadata<BaseAsset, QuoteAsset>>)

```

## Rationale

For deepbook to be fully integrable by any protocol for order matching, it should provide getters for all information on-chain. Currently, OrderFilledEvents captures order matching information & only emits it as event. But having this information only as an event, can lead to security issues & attacks since data from events is read-only and cannot be acted upon deterministically on-chain. To rule out such cases, an on-chain hook is required which third parties can use to impose custom checks on top of deepbook order matching. Knowing counterparty on chain is important use case for both spot and perp (enables instant p2p settlement). This design change would also de-couple custom requirements from third party protocols on deepbook since it enables them to put checks in their own packages without requiring changes in deepbook's base package.

## Backwards Compatibility

This SIP presents no issues with backwards compatibility.

## Test Cases

Unit tests have been added to fully test the proposed changes. 

## Security Considerations

Vector length limit should be verified in case of multiple matched orders as an edge case. 

## Copyright

[CC0 1.0.](https://github.com/sui-foundation/sips/blob/main/LICENSE.md)
