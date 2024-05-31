| SIP-Number          | 31 |
| ---:                | :--- |
| Title               | Fungible StakedSui objects |
| Description         | Allow StakedSui objects to be transformed into a FungibleStake object, which is epoch independent. |
| Author              | ripleys <0xripleys@solend.fi> |
| Editor              | Amogh Gupta <amogh@sui.io, @amogh-sui>  |
| Type                | Standard |
| Category            | Framework |
| Created             | 2024-05-23 |
| Comments-URI        | https://sips.sui.io/comments-31 |
| Status              | Draft |
| Requires            | NA |

## Abstract

Allow StakedSui objects to be transformed into an Fungible object, which are fungible and epoch independent. This improves efficiency for anyone working with a large amount of StakedSui objects, primarily liquid staking derivative contracts.

## Motivation

Currently, StakedSui objects are tied to a specific activation epoch. If two StakedSui objects are from different activation epochs, they cannot be merged together. 

This is annoying for anyone working with a large amount of StakedSui objects, primarily liquid staking derivative (LST) contracts. Currently, any LST contract now has to manage O(n) StakedSui objects _per_ validator, where n is the number of epochs since genesis. See [the vSui implementation](https://github.com/Sui-Volo/volo-liquid-staking-contracts/blob/main/liquid_staking/sources/validator_set.move#L45) for reference. This is inefficient, as any LST unstake operation can now touch a large amount of StakedSui objects.

## Specification

[staking_pool.move](https://github.com/MystenLabs/sui/blob/main/crates/sui-framework/packages/sui-system/sources/staking_pool.move)

```move

    /// An FungibleStake object with a value of 1 corresponds to 1 pool token in the Staking pool.
    /// This can be a Coin! See the Rationale below.
    public struct FungibleStake has key, store {
        id: UID,
        /// ID of the staking pool we are staking with.
        pool_id: ID,
        /// The pool token amount.
        value: u64,
    }


    /// Dynamic field on the StakingPool Struct.
    public struct FungibleStakeData has key, store {
        id: UID,
        /// fungible_stake supply. sum of values across all FungibleStake objects in the pool.
        fungible_stake_supply: u64,
        /// principal balance. Rewards are not stored here, they are withdrawn from the StakingPool's reward pool.
        principal: Balance<SUI>,
    }

    // === dynamic field keys ===
    public struct FungibleStakeDataKey has copy, store, drop {}

    // === Public getters ===
    public fun fungible_stake_value(fungible_stake: &FungibleStake): u64 {
        fungible_stake.value
    }

    public fun fungible_stake_pool_id(fungible_stake: &FungibleStake): ID {
        fungible_stake.pool_id
    }

    public fun fungible_stake_to_sui_amount(pool: &StakingPool, fungible_stake_amount: u64): u64;
    public fun sui_to_fungible_stake_amount(pool: &StakingPool, sui_amount: u64): u64;

    public fun join_fungible_stake(self: &mut FungibleStake, other: FungibleStake);
    public fun split_fungible_stake(self: &mut FungibleStake, amount: u64): FungibleStake;

    /// Burn an FungibleStake object to obtain the underlying SUI.
    public(package) fun redeem_fungible_stake(pool: &mut StakingPool, fungible_stake: FungibleStake, ctx: &TxContext) : Balance<SUI>;

    /// Convert the given staked SUI to an FungibleStake object
    public(package) fun convert_to_fungible_stake(pool: &mut StakingPool, staked_sui: StakedSui, ctx: &mut TxContext) : FungibleStake;

```

[validator.move](https://github.com/MystenLabs/sui/blob/main/crates/sui-framework/packages/sui-system/sources/validator.move)

```move
    public(package) fun convert_to_fungible_stake(self: &mut Validator, staked_sui: StakedSui, ctx: &TxContext) : FungibleStake;
    public(package) fun redeem_fungible_stake(self: &mut Validator, fungible_stake: FungibleStake, ctx: &TxContext) : Balance<SUI>;
```

[validator_set.move](https://github.com/MystenLabs/sui/blob/main/crates/sui-framework/packages/sui-system/sources/validator_set.move)

```move
    public(package) fun convert_to_fungible_stake(self: &mut ValidatorSet, staked_sui: StakedSui, ctx: &TxContext) : FungibleStake;
    public(package) fun redeem_fungible_stake(self: &mut ValidatorSet, fungible_stake: FungibleStake, ctx: &TxContext) : Balance<SUI>;
```

[sui_system_state_inner.move](https://github.com/MystenLabs/sui/blob/main/crates/sui-framework/packages/sui-system/sources/sui_system_state_inner.move)

```move
    public(package) fun convert_to_fungible_stake(self: &mut SuiSystemStateInnerV2, staked_sui: StakedSui, ctx: &TxContext) : FungibleStake;
    public(package) fun redeem_fungible_stake(self: &mut SuiSystemStateInnerV2, fungible_stake: FungibleStake, ctx: &TxContext) : Balance<SUI>;
```

It's possible I missed some getter functions, but I think this is the gist of it.

## Rationale

### Instead of the FungibleStake object, why don't we just mint a new "LST" Coin per StakingPool?

This is possible and I really like this idea. The main benefit of doing this is that it would immediately enable single-validator LSTs for the entire validator set, which would be pretty cool.

The tricky part would be managing a unique Coin type + metadata per StakingPool. Some notes:
- We would need a one time witness per StakingPool to create the Coin type. This can be passed into the StakingPool on instantiation.
- For existing StakingPool objects, there would need to be a function to create this one time witness and pass it to the StakingPool. I strongly feel that this function should be able to be called permissionlessly. The effectiveness of this SIP is greatly diminished if each validator has to opt into this feature. I don't think this can be abused, as the StakingPool would be calling the `coin::create_currency` function anyways, so the CoinMetadata is completely under our control.

The one caveat to this approach is that there is a warmup period (up to one epoch) before a newly created StakedSui object can be converted into an LST coin. UX-wise, this isn't great. However I don't think this is a dealbreaker, as existing StakedSui objects can be immediately converted into these tokens, and if LST minting is required, that can be done as a separate contract.

### Why can't the StakedSui principal be stored directly on the FungibleStake object? Why is a dynamic field necessary?

The first reason is that I really like the Coin approach, which would require a dynamic field to hold the principal anyways.

The second reason is that splitting FungibleStake objects now becomes potentially expoitable. Eg say you have an FungibleStake object with value 1.2e10, and principal of 1e10. If you want to split the FungibleStake object into 3 equal parts, where should the extra MIST of principal go? All answers feel unsatisfactory to me.

### Misc
- `redeem_fungible_stake` could return an StakedSui object instead. I need to double check the math here to make sure it's safe. I think just returning a StakedSui object that's activated in the current epoch is fine (ie all principal, no rewards).
- If we want these interfaces to be compatible with any future unbonding period implementation, we could return a LockedSui object instead of the Sui in `redeem_fungible_stake`. Or, just return the StakedSui object like I mentioned above.

## Backwards Compatibility

No issues with backwards compatibility. This SIP only adds features, and does not change existing ones.

## Reference Implementation

See [here](https://github.com/0xripleys/sui/pull/1/files) for a reference implementation of how the staking pool code would look like.

Note that this implementation just a Draft and is not production ready. 

## Security Considerations

The potential damage of a bug in staking_pool.move is higher as we now store a nontrivial amount of Sui in this module. Also, we definitely need to be careful with the math around redeem_lst. Both can be mitigated with an audit.
