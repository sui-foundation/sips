|   SIP-Number | 6                                                                                                                                                                |
| -----------: | :--------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|        Title | `StakedSui` Improvements                                                                                                                                         |
|  Description | Improvements to the `StakedSui` object, including giving it the `store` ability and secondary functions into the staking flow that return the `StakedSui` object |
|       Author | Kevin <github@aftermath.finance, @admin-aftermath>, Aftermath Finance <[aftermath.finance](https://aftermath.finance/)>                                          |
|       Editor | Will Riches <will@sui.io, @wriches>                                                                                                                              |
|         Type | Standard                                                                                                                                                         |
|     Category | Framework                                                                                                                                                        |
|      Created | 2023-06-07                                                                                                                                                       |
| Comments-URI | https://sips.sui.io/comments-6                                                                                                                                   |
|       Status | Final                                                                                                                                                            |
|     Requires | N/A                                                                                                                                                              |

## Abstract

This SIP specifies improvements to the `StakedSui` struct and associated functions. The existing implementation is limited in its overall composability and inevitably leads to less transparent, custodial extensions of Sui staking.

This SIP tries not to stick to one domain when considering these changes, but rather provides improvements that will enable a new possibility of extensions to be made to Sui's staking mechanism.

> As Sui will continue to evolve over time, a snapshot of the Sui repo will be used when referencing Sui Framework code. This SIP uses the latest stable version of mainnet: `mainnet-v1.2.1`.<sup>[1](https://github.com/MystenLabs/sui/tree/mainnet-v1.2.1)</sup>

## Background

**Proof-of-Stake.** The Sui network utilizes a Delegated Proof-of-Stake (POS) consensus mechanism to determine the active validator set. Users can delegate SUI to the validator of their choice to increase the validator's voting power. Every epoch, transaction gas fees and stake subsidies are redistributed back to the validators and their delegators.

**Staked Sui.** By delegating to a validator, a user receives a `StakedSui` object that acts as a receipt to their position. This `StakedSui` object accrues rewards when the epoch advances and can be redeemed at will by its owner. Currently, the `StakedSui` struct is implemented as follows<sup>[2](https://github.com/MystenLabs/sui/blob/mainnet-v1.2.1/crates/sui-framework/packages/sui-system/sources/staking_pool.move#L80-L89)</sup>:

```Rust
/// A self-custodial object holding the staked SUI tokens.
struct StakedSui has key {
    id: UID,
    /// ID of the staking pool we are staking with.
    pool_id: ID,
    /// The epoch at which the stake becomes active.
    stake_activation_epoch: u64,
    /// The staked SUI tokens.
    principal: Balance<SUI>,
}
```

The corresponding functions that deal with staking `Coin<SUI>` are `entry` functions and thus directly transfer the resulting `StakedSui` back to the sender.

## Motivation

**Transparency.** Without the `store` ability on `StakedSui`, projects building on top of the native Sui staking mechanics require a centralized address to store the `StakedSui` objects. This will limit the overall reach of these projects due to the high level of trust required for a user to feel comfortable in interacting with their product. In some cases this can also lead to a loss of funds, if the keys for the centralized account are lost or stolen.

&nbsp;&nbsp;&nbsp;&nbsp; In order to enable truly trustless, transparent, and composable extensions of Sui staking, the `StakedSui` struct requires the `store` ability. This change moves the underlying, extrinsic trust in the project to the inherent safety in the relevant Sui Move modules. Trust can only be reassured, while smart contracts can go through many rounds of audits and tests to prove correctness.

**Composability.** In order to allow the use of `StakedSui` flows in programmable transactions, `public`, non-`entry` variations of `request_add_stake` and `request_add_stake_mul_coins` are required that directly return the `StakedSui` objects. Without these functions, the inclusivity of Sui staking flows are limited within programmable txs.

**Expressiveness.** By design, `StakedSui` is yield-bearing: every epoch an amount of `Coin<SUI>` rewards is distributed to each Validator's `StakingPool` to be later redeemed by unstaking a `StakedSui` position. A natural requirement for any protocol utilizing `StakedSui` is to determine the total value (i.e. principal + reward) accrued in the position. Currently, there exists a function to query the underlying principal value of a `StakedSui` object but not to query accrued rewards or the state of the associated `StakingPool`.

&nbsp;&nbsp;&nbsp;&nbsp; To enable better on-chain interaction with `StakedSui` objects, additional `sui_system` getter functions are required.

## Prerequisites

In order to upgrade a package, your changes must satisfy a list of requirements. Adding new abilities to existing structs is strictly prohibited and thus, as it stands, **adding `store` to `StakedSui` will not pass the upgrade verification check**. To get around this, upgrades for _only_ the `sui_system` package should have a relaxed set of requirements.

## Specification

The upgrade requirements for the `sui_system` package (`0x3`) will be relaxed and the `store` ability will be added to the implementation of the `StakedSui` struct.

Secondary functions will be added for `request_add_stake` and `request_add_stake_mul_coins` that return their resulting `StakedSui` instead of automatically being transferred back to the sender.

A `#[test_only]` function, `calculate_rewards`, will be modified to be accessible onchain. Accordingly, a `sui_system.move` -> `staking_pool.move` flow will be added to support the calling of `calculate_rewards`. Also, `PoolTokenExchangeRate` getters will be added to allow historic and future exchange rate calculations and functions will be added to expose querying of the active validator set.

## Rationale

With the `store` ability, dApps extending upon Sui staking can now store all `StakedSui` objects with a shared object and maintain all of their logic onchain without the need for a centralized, custodial address. The `store` ability inherently presents its own concerns (which are further elaborated in **Security Considerations**).

Without the ability to accurately value `StakeSui` objects onchain, the overall composability of the `sui_system` package is limited. The `sui_system` was abstracted in a way to enable upgrading the underlying structs (e.g. `ValidatorSet`, `StakingPool`, ...) without having to leave legacy code within the upgraded modules. By exposing functions for the `PoolTokenExchangeRate` struct directly, future `StakingPool` upgrades can still occur without the need to provide support for legacy `StakingPool`-related getters and a new level of functionality with the validator set is unlocked.

## Backwards Compatibility

This SIP presents no issues with backwards compatibility.

## Reference Implementation

We have created a fork of the Sui repo to implement these specifications; the relevant changes are detailed below:

### i. Changes to `StakedSui`

The `StakedSui` object needs the `store` ability.

```Rust
/// A self-custodial object holding the staked SUI tokens.
struct StakedSui has store, key {
    id: UID,
    /// ID of the staking pool we are staking with.
    pool_id: ID,
    /// The epoch at which the stake becomes active.
    stake_activation_epoch: u64,
    /// The staked SUI tokens.
    principal: Balance<SUI>,
}
```

### ii. Changes to SUI staking/unstaking flow

To enable seemless composability with prog. txs, `request_add_stake` and `request_add_stake_mul_coin` should have an adjacent flow that directly return their respective `StakedSui` objects, rather than transferring back to the sender. The changes to these two are nearly identical, therefore only the updates to the `request_add_stake` flow are shown here:

**sui_system.** A `public`, non-`entry` variant of the `request_add_stake` function needs to be added that will return the created `StakedSui` object.

```Rust
/// Add stake to a validator's staking pool.
public fun request_add_stake_non_entry(
    wrapper: &mut SuiSystemState,
    stake: Coin<SUI>,
    validator_address: address,
    ctx: &mut TxContext,
): StakedSui {
    let self = load_system_state_mut(wrapper);

    sui_system_state_inner::request_add_stake(self, stake, validator_address, ctx)
}

/// Add stake to a validator's staking pool.
public entry fun request_add_stake(
    wrapper: &mut SuiSystemState,
    stake: Coin<SUI>,
    validator_address: address,
    ctx: &mut TxContext,
) {
    let staked_sui = request_add_stake_non_entry(wrapper, stake, validator_address, ctx);

    transfer::public_transfer(staked_sui, tx_context::sender(ctx));
}
```

**sui_system_state_inner.** `sui_system_state_inner::request_add_stake` needs to return the `StakedSui` object.

```Rust
/// Add stake to a validator's staking pool.
public(friend) fun request_add_stake(
    self: &mut SuiSystemStateInnerV2,
    stake: Coin<SUI>,
    validator_address: address,
    ctx: &mut TxContext,
): StakedSui {
    validator_set::request_add_stake(
        &mut self.validators,
        validator_address,
        coin::into_balance(stake),
        ctx,
    )
}
```

**validator_set.** `validator_set::request_add_stake` needs to return the `StakedSui` object.

```Rust
/// Called by `sui_system`, to add a new stake to the validator.
/// This request is added to the validator's staking pool's pending stake entries, processed at the end
/// of the epoch.
/// Aborts in case the staking amount is smaller than MIN_STAKING_THRESHOLD
public(friend) fun request_add_stake(
    self: &mut ValidatorSet,
    validator_address: address,
    stake: Balance<SUI>,
    ctx: &mut TxContext,
): StakedSui {
    let sui_amount = balance::value(&stake);
    assert!(sui_amount >= MIN_STAKING_THRESHOLD, EStakingBelowThreshold);

    let validator = get_candidate_or_active_validator_mut(self, validator_address);
    validator::request_add_stake(validator, stake, tx_context::sender(ctx), ctx)
}
```

**validator.** `validator::request_add_stake` needs to return the `StakedSui` object.

```Rust
/// Request to add stake to the validator's staking pool, processed at the end of the epoch.
public(friend) fun request_add_stake(
    self: &mut Validator,
    stake: Balance<SUI>,
    staker_address: address,
    ctx: &mut TxContext,
): StakedSui {
    ...
    let staked_sui = staking_pool::request_add_stake(
        &mut self.staking_pool, stake, stake_epoch, ctx
    );

    ...

    event::emit(
        StakingRequestEvent {
            pool_id: staking_pool_id(self),
            validator_address: self.metadata.sui_address,
            staker_address,
            epoch: tx_context::epoch(ctx),
            amount: stake_amount,
        }
    );

    staked_sui
}
```

**staking_pool.** `request_add_stake::request_add_stake` needs to return the created `StakedSui` object.

```Rust
/// Request to stake to a staking pool. The stake starts counting at the beginning of the next epoch,
public(friend) fun request_add_stake(
    pool: &mut StakingPool,
    stake: Balance<SUI>,
    stake_activation_epoch: u64,
    ctx: &mut TxContext
): StakedSui {
    let sui_amount = balance::value(&stake);
    assert!(!is_inactive(pool), EDelegationToInactivePool);
    assert!(sui_amount > 0, EDelegationOfZeroSui);

    pool.pending_stake = pool.pending_stake + sui_amount;

    StakedSui {
        id: object::new(ctx),
        pool_id: object::id(pool),
        stake_activation_epoch,
        principal: stake,
    }
}
```

The above example follows the notation set by an implementation of the `request_withdraw_stake` flow that returns `Balance<SUI>` which, at the time of writing, has just been included into Sui version `testnet-v1.3.0`.<sup>[3](https://github.com/MystenLabs/sui/pull/12092)</sup>

### iii. `sui_system` getters

#### iiia. `calculate_rewards` function

**sui_system.** A top level `public` function, `calculate_rewards`, will be added as a wrapper around the flow that will call `staking_pool::calculate_rewards`. This function will allow other contracts to calculate the rewards that a `StakedSui` object is entitled to.

```Rust
/// Given the `staked_sui` receipt calculate the current rewards (in terms of SUI) for it.
public fun calculate_rewards(wrapper: &mut SuiSystemState, staked_sui: &StakedSui): u64 {
    let self = load_system_state(wrapper);

    sui_system_state_inner::calculate_rewards(self, staked_sui)
}
```

**sui_system_state_inner.** Following the design of other `sui_system` functions, a corresponding `calculate_rewards` function will be added to `sui_system_state_inner.move`.

```Rust
/// Given the `staked_sui` receipt calculate the current rewards (in terms of SUI) for it.
public(friend) fun calculate_rewards(self: &SuiSystemStateInnerV2, staked_sui: &StakedSui): u64 {
    let validators = &self.validators;
    let epoch = epoch(self);

    validator_set::calculate_rewards(validators, staked_sui, epoch)
}
```

**validator_set.** Similarly, a corresponding `calculate_rewards` function will be added to `validator_set.move`.

```Rust
/// Given the `staked_sui` receipt calculate the current rewards (in terms of SUI) for it.
public(friend) fun calculate_rewards(self: &ValidatorSet, staked_sui: &StakedSui, epoch: u64): u64 {
    let staking_pool_id = pool_id(staked_sui);
    let mapping = &self.staking_pool_mappings;

    // If there is no such staking pool id in the staking pool id -> validator mapping
    // return zero.
    if (!table::contains(mapping, staking_pool_id)) {
        return 0
    };

    let validator_address = *table::borrow(mapping, staking_pool_id);
    // There are no rewards if validator is not active.
    if (!is_active_validator_by_sui_address(self, validator_address)) {
        return 0
    };

    let validator = get_active_validator_ref(self, validator_address);
    let staking_pool = validator::get_staking_pool_ref(validator);

    staking_pool::calculate_rewards(staking_pool, staked_sui, epoch)
}
```

**validator.** The `#[test_only]` function `get_staking_pool_ref` will become `public(friend)` and `#[test_only]` will be removed so it can now be called before calling `staking_pool::calculate_rewards`.

```Rust
public(friend) fun get_staking_pool_ref(self: &Validator) : &StakingPool {
    &self.staking_pool
}
```

**staking_pool.** The `#[test_only]` function `calculate_rewards` will become `public(friend)` and `#[test_only]` will be removed, allowing the function to be called onchain by friend modules. Also, note that the function now returns the calculated rewards (i.e. `reward_withdraw_amount`) and doesn't include the `StakedSui`'s principal amount.

```Rust
/// Given the `staked_sui` receipt calculate the current rewards (in terms of SUI) for it.
public(friend) fun calculate_rewards(
    pool: &StakingPool,
    staked_sui: &StakedSui,
    current_epoch: u64,
): u64 {
    let staked_amount = staked_sui_amount(staked_sui);
    let pool_token_withdraw_amount = {
        let exchange_rate_at_staking_epoch = pool_token_exchange_rate_at_epoch(pool, staked_sui.stake_activation_epoch);
        get_token_amount(&exchange_rate_at_staking_epoch, staked_amount)
    };

    let new_epoch_exchange_rate = pool_token_exchange_rate_at_epoch(pool, current_epoch);
    let total_sui_withdraw_amount = get_sui_amount(&new_epoch_exchange_rate, pool_token_withdraw_amount);

    let reward_withdraw_amount =
        if (total_sui_withdraw_amount >= staked_amount)
            total_sui_withdraw_amount - staked_amount
        else 0;
    reward_withdraw_amount = math::min(reward_withdraw_amount, balance::value(&pool.rewards_pool));

    reward_withdraw_amount
}
```

#### iiib. `PoolTokenExchangeRate` getters

**sui_system.** A top level getter will be added that enables querying of the historic exchange rates associated with a `StakedSui`'s `StakingPool`.

```Rust
public fun pool_exchange_rates(
    wrapper: &mut SuiSystemState,
    staking_pool_id: ID
): &Table<u64, PoolTokenExchangeRate>  {
    let self = load_system_state(wrapper);
    sui_system_state_inner::pool_exchange_rates(self, staking_pool_id)
}
```

**sui_system_inner.** The underlying function will also be added.

```Rust
public fun pool_exchange_rates(
    self: &SuiSystemStateInnerV2,
    staking_pool_id: ID 
): &Table<u64, PoolTokenExchangeRate>  {
    let validators = &self.validators;
    validator_set::pool_exchange_rates(validators, staking_pool_id)
}
```


```Rust
public(friend) fun pool_exchange_rates(
    self: &ValidatorSet,
    staking_pool_id: ID,
): &Table<u64, PoolTokenExchangeRate>  {
    let mapping = &self.staking_pool_mappings;
    let validator_address = *table::borrow(mapping, staking_pool_id);

    let validator = get_active_validator_ref(self, validator_address);

    let staking_pool = validator::get_staking_pool_ref(validator);
    staking_pool::exchange_rates(staking_pool)
}
```

**staking_pool.** The following functions will be added to enable third-party interaction with `staking_pool::pool_token_exchange_rate_at_epoch` and the `PoolTokenExchangeRate` struct.

```Rust
public fun exchange_rates(pool: &StakingPool): &Table<u64, PoolTokenExchangeRate> {
    &pool.exchange_rates
}

public fun sui_amount(exchange_rate: &PoolTokenExchangeRate): u64 {
    exchange_rate.sui_amount
}

public fun pool_token_amount(exchange_rate: &PoolTokenExchangeRate): u64 {
    exchange_rate.pool_token_amount
}
```

#### iiic. Active validator getters

**sui_system.** The following function will be added to allow onchain querying of the active validator set. 

``` Rust
public fun active_validator_addresses(wrapper: &mut SuiSystemState): vector<address> {
    let self = load_system_state(wrapper);

    sui_system_state_inner::active_validator_addresses(self)
}
```

**sui_system_inner.** The equivalent function will be added to `sui_system_inner.move`.

```Rust
public(friend) fun active_validator_addresses(self: &SuiSystemStateInnerV2): vector<address> {
    let validators = &self.validators;

    validator_set::active_validator_addresses(validators)
}
```

**validator_set.** The following function will become `public(friend)` and `#[test_only]` will be removed.

```Rust
public(friend) fun active_validator_addresses(self: &ValidatorSet): vector<address> {
    let vs = &self.active_validators;
    let res = vector[];
    let i = 0;
    let length = vector::length(vs);
    
    while (i < length) {
        let validator_address = validator::sui_address(vector::borrow(vs, i));
        
        vector::push_back(&mut res, validator_address);
        i = i + 1;
    };
    res
}
```

## Security Considerations

When adding the `store` ability to any Sui Move object, users and developers must consider the negative possibilities of modules now being able to store the object. In the case of `StakedSui`, the owner of the `StakedSui` object is the only one able to withdraw its principal and rewards; for this reason, giving `StakedSui` the `store` ability now forces a heightened level of trust between a user and a module that will be persistently storing `StakedSui`.

dApps that will compose off of native Sui staking and utilize the `store` ability should be thoroughly audited and tested before being published on mainnet. Users that aim to use these protocols should understand both the risks of transferring their `StakedSui` to a module and the implications of mutable packages on the safety of their `StakedSui`.<sup>[4](https://github.com/MystenLabs/sui/issues/2045)</sup> Before interacting with any protocol that extends upon Sui staking, a user should perform their own checks on the presence and number of audits, the level of testing thoroughness and the mutability of the relevant packages. As such, protocols should make this info readily available to the average user.

Third party apps that want to simply provide an interface to native Sui staking (e.g. wallets, explorers) should continue to use the `request_stake_sui`, `request_stake_sui_mul_coins`, and `request_withdraw_sui` `entry` functions. For a user strictly interacting with these applications, there are no extra security considerations.

## References

1. [[Sui Repo] mainnet-v1.2.1](https://github.com/MystenLabs/sui/tree/mainnet-v1.2.1)
2. [[Sui Repo] `StakedSui`](https://github.com/MystenLabs/sui/blob/mainnet-v1.2.1/crates/sui-framework/packages/sui-system/sources/staking_pool.move#L80-L89)
3. [[Sui Repo] `request_withdraw_stake_non_entry`](https://github.com/MystenLabs/sui/pull/12092)
4. [[Move] Third-Party Package upgrades](https://github.com/MystenLabs/sui/issues/2045)

## Copyright

[CC0 1.0](../LICENSE.md).
