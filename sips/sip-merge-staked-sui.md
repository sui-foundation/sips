| SIP-Number          | <Leave this blank; it will be assigned by a SIP Editor> |
| ---:                | :--- |
| Title               | Merge StakedSui objects across different activation epochs |
| Description         | Allow StakedSui objects to be transformed into an Lst object, which is epoch independent. |
| Author              | ripleys <0xripleys@solend.fi> |
| Editor              | <Leave this blank; it will be assigned by a SIP Editor> |
| Type                | Standard |
| Category            | Framework |
| Created             | 2024-05-23 |
| Comments-URI        | <Leave this blank; it will be assigned by a SIP Editor> |
| Status              | <Leave this blank; it will be assigned by a SIP Editor> |
| Requires            | <Optional; SIP number(s), comma separated> |

## Abstract

Allow StakedSui objects to be transformed into an Lst object, which are fungible and epoch independent. This improves efficiency for anyone working with a large amount of StakedSui objects, primarily liquid staking derivative contracts.

## Motivation

Currently, StakedSui objects are tied to a specific activation epoch. If two StakedSui objects are from different activation epochs, they cannot be merged together. 

This is annoying for anyone working with a large amount of StakedSui objects, primarily liquid staking derivative (LST) contracts. Currently, any LST contract now has to manage O(n) StakedSui objects _per_ validator, where n is the number of epochs since genesis. See [the vSui implementation](https://github.com/Sui-Volo/volo-liquid-staking-contracts/blob/main/liquid_staking/sources/validator_set.move#L45) for reference. This is inefficient, as any LST unstake operation can now touch a large amount of StakedSui objects.

## Specification

[staking_pool.move](https://github.com/MystenLabs/sui/blob/main/crates/sui-framework/packages/sui-system/sources/staking_pool.move)

```move

    /// An Lst object with a value of 1 corresponds to 1 pool token in the Staking pool.
    /// This can be a Coin! See rationale below.
    public struct Lst has key, store {
        id: UID,
        /// ID of the staking pool we are staking with.
        pool_id: ID,
        /// The pool token amount.
        value: u64,
    }


    /// Dynamic field on the StakingPool Struct.
    public struct LstData has key, store {
        id: UID,
        /// lst supply
        lst_supply: u64,
        /// principal balance. Rewards are not stored here, they are withdrawn from the StakingPool's reward pool.
        principal: Balance<SUI>,
    }

    // === dynamic field keys ===
    public struct LstDataKey has copy, store, drop {}

    // === Public getters ===
    public fun lst_value(lst: &Lst): u64 {
        lst.value
    }

    public fun lst_pool_id(lst: &Lst): ID {
        lst.pool_id
    }

    public fun lst_to_sui_amount(pool: &StakingPool, lst_amount: u64): u64;
    public fun sui_to_lst_amount(pool: &StakingPool, sui_amount: u64): u64;

    /// Burn an Lst object to obtain the underlying SUI.
    public(package) fun redeem_lst(pool: &mut StakingPool, lst: Lst, ctx: &TxContext) : Balance<SUI>;

    /// Convert the given staked SUI to an Lst object
    public(package) fun mint_lst(pool: &mut StakingPool, staked_sui: StakedSui, ctx: &mut TxContext) : Lst;

```

[validator.move](https://github.com/MystenLabs/sui/blob/main/crates/sui-framework/packages/sui-system/sources/validator.move)

```move
    public(package) fun mint_lst(self: &mut Validator, staked_sui: StakedSui, ctx: &TxContext) : Lst;
    public(package) fun redeem_lst(self: &mut Validator, lst: Lst, ctx: &TxContext) : Balance<SUI>;
```

[validator_set.move](https://github.com/MystenLabs/sui/blob/main/crates/sui-framework/packages/sui-system/sources/validator_set.move)

```move
    public(package) fun mint_lst(self: &mut ValidatorSet, staked_sui: StakedSui, ctx: &TxContext) : Lst;
    public(package) fun redeem_lst(self: &mut ValidatorSet, lst: Lst, ctx: &TxContext) : Balance<SUI>;
```

[sui_system_state_inner.move](https://github.com/MystenLabs/sui/blob/main/crates/sui-framework/packages/sui-system/sources/sui_system_state_inner.move)

```move
    public(package) fun mint_lst(self: &mut SuiSystemStateInnerV2, staked_sui: StakedSui, ctx: &TxContext) : Lst;
    public(package) fun redeem_lst(self: &mut SuiSystemStateInnerV2, lst: Lst, ctx: &TxContext) : Balance<SUI>;
```

[sui_system.move](https://github.com/MystenLabs/sui/blob/main/crates/sui-framework/packages/sui-system/sources/sui_system.move)

```move
    public(package) fun mint_lst(self: &mut SuiSystemState, staked_sui: StakedSui, ctx: &TxContext) : Lst;
    public(package) fun redeem_lst(self: &mut SuiSystemState, lst: Lst, ctx: &TxContext) : Balance<SUI>;
```


## Rationale

#### Instead of the Lst object, why don't we just mint a new Coin?

This is possible and I really like this idea. The main benefit of doing this is that it would immediately enable single-validator LSTs for the entire validator set, which would be pretty cool.

The tricky part would be managing a unique Coin type + metadata per StakingPool. Some notes:
- We would need a one time witness per StakingPool to create the Coin type. This can be passed into the StakingPool on instantiation.
- For existing StakingPool objects, there would need to be a function to create this one time witness and pass it to the StakingPool. I strongly feel that this function should be able to be called permissionlessly. The effectiveness of this SIP is greatly diminished if each validator has to opt into this feature. I don't think this can be abused, as the StakingPool would be calling the `coin::create_currency` function anyways, so the CoinMetadata is completely under our control.

The one caveat to this approach is that there is a warmup period (up to one epoch) before a newly created StakedSui object can be converted into an LST coin. UX-wise, this isn't great. However I don't think this is a dealbreaker, as existing StakedSui objects can be immediately converted into these tokens, and if LST minting is required, that can be done as a separate contract.

#### Why can't the StakedSui principal be stored directly on the Lst object? Why is a dynamic field necessary?

The first reason is that I really like the Coin approach, which would require a dynamic field to hold the principal anyways.

The second reason is that splitting Lst objects now becomes potentially expoitable. Eg say you have an Lst object with value 1.2e10, and principal of 1e10. If you want to split the Lst object into 3 equal parts, where should the extra MIST of principal go? All answers feel unsatisfactory to me.

## Backwards Compatibility

No issues with backwards compatibility. This SIP only adds features, and does not change existing ones.

## Reference Implementation

See [here](https://github.com/0xripleys/sui/pull/1/files) for a reference implementation of how the staking pool code would look like.

Note that this is just a Draft and is not production ready. 

## Security Considerations

The potential damage of a bug in staking_pool.move is higher as we now store a nontrivial amount of Sui in this module. Also, we definitely need to be careful with the math around redeem_lst. Both can be mitigated with an audit.

## Copyright

TODO not sure what to put here yet. But please don't steal my work lol
