| SIP-Number          | 33 |
| ---:                | :--- |
| Title               | Allow inactive StakedSui objects to be redeemed immediately |
| Description         | Currently, a StakedSui object cannot be created and redeemed in the same epoch, which is an unncessary restriction. |
| Author              | ripleys <0xripleys@solend.fi> |
| Editor              | Amogh Gupta <amogh@sui.io, @amogh-sui> |
| Type                | Standard |
| Category            | Framework |
| Created             | 29-05-2024 |
| Comments-URI        | https://sips.sui.io/comments-33 |
| Status              | Review|
| Requires            |NA|

## Abstract

A StakedSui object cannot be created and redeemed in the same epoch due to [this](https://github.com/MystenLabs/sui/blob/main/crates/sui-framework/packages/sui-system/sources/sui_system_state_inner.move#L519) assertion. This is an unncessary restriction that reduces LST efficiency and prevents instant unstaking of LSTs.

## Motivation

### LST Inefficiency

Suppose there exists an LST (lets call it xSUI) that holds 1 active StakedSui object. An active StakedSui object means that the object is currently earning rewards in this epoch. 

Now, a user comes and and mints some xSui. The LST now holds 1 active StakedSui object and 1 inactive StakedSui object.

Now, in the same epoch, the user wants to redeem the xSUI for its underlying SUI. From the LST perspective, it is better to convert the inactive StakedSui object to Sui and give it to the user, as this object is not earning rewards yet. If the LST redeems part of the _active_ StakedSui object instead, it loses 1 epoch of rewards.

### Prevents Instant Unstaking of entire xSUI supply.

Definition: Instant unstaking is the ability to instantly convert xSUI to Sui.

This restriction prevents any LST from implementing instant unstaking of the entire xSUI supply. Currently, vSUI and afSUI implement instant unstaking but only up to a certain amount, depending on the percentage of supply (vSUI) or the amount of Sui reserves (afSUI). 

Currently, if an LST allowed instant unstaking of the entire supply, a malicious user could mint a really large supply of xSUI, unstake it all, and leave the LST with only inactive StakedSui objects, which cannot be redeemed until the next epoch. While this is likely a costly attack due to fees, and isn't really an "attack" since there are no loss of funds, it's still very annoying as the instant unstaking feature is now broken until next epoch.

Why is instant unstaking useful?

- There is no longer a need to provide liquidity on xSui/{Sui, USDC, USDT} pairs on DEXes. Instead, all LSTs share the same Sui liquidity. This is a big benefit for new entrants to the LST space, as they no longer need to source millions of dollars to provide liquidity on their xSui pairs.
- LSTs that implement instant unstaking cannot depeg due to liquidity conditions. This makes the product much more usable across the defi ecosystem. LST depegs are a big source of risk in lending and any leveraged staking product.


## Specification

Remove [this](https://github.com/MystenLabs/sui/blob/main/crates/sui-framework/packages/sui-system/sources/sui_system_state_inner.move#L519)  assertion.

In [staking_pool.move](https://github.com/MystenLabs/sui/blob/mainnet-v1.2.1/crates/sui-framework/packages/sui-system/sources/staking_pool.move#L137), the `request_withdraw_stake` will need extra logic to handle the case where the StakedSui object was created in the current epoch. But that is very straightforward to do.

## Rationale

This change is fairly minor, and there's no other way to implement the suggestions in this SIP.

## Backwards Compatibility

No interfaces are changing here.

## Reference Implementation

https://github.com/MystenLabs/sui/pull/18265

## Security Considerations

This change does not affect security.
