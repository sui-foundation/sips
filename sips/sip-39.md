| SIP-Number          | 39                                                            |
| ------------------: | :--------------------------------------------------------     |
| Title               | Lowering the validator set barrier to entry                   |
| Description         | Use a min voting power threshold instead of min SUI threshold |
| Author              | Sam Blackshear <@sblackshear>                                 |
| Editor              | Amogh Gupta <amogh@sui.io, @amogh-sui>                        |
| Type                | Standard                                                      |
| Category            | Framework                                                     |
| Created             | 2024-08-11                                                    |
| Comments-URI        | https://sips.sui.io/comments-39                               |
| Status              | Final                                                         |
| Requires            |                                                               |

## Abstract
Lower the barrier to entry for validators by requiring a minimum amount of *voting power* instead of a minimum amount of SUI.

## Motivation
To enter the validator set, a new Sui validator needs to accumulate 30M SUI in delegated stake. This large amount makes it too difficult for new validators to join Sui.

## Proposal
Lower the barrier to entry for validators by requiring a minimum amount of *voting power* instead of a minimum amount of SUI.

As background:

* Sui uses a delegated proof of stake system with stake-weighted voting.
* For convenient accounting, Sui normalizes the total amount staked to 10,000 units of voting power, and allocates each validator voting power proportional to their delegated stake. A Sui transaction or checkpoint is finalized when it receives signatures from validators whose combined voting power is >6,666.
* A validator must acquire at least 30M SUI to join the validator set

Note that a validator with 0 voting power has no influence. Thus, a natural precondition for admitting a new validator is requiring enough stake to have nonzero voting power after joining. Specifically, we propose to allow any validator candidate whose stake corresponds to some minimum voting power threshold **V** enter the set. In detail:

* Say the total amount staked in Sui is **T**, and a validator candidate has amassed **S** delegated stake
* If **S / (S + T) > V / 10000**, the candidate validator is allowed to enter the validator set. Intuitively, this says that if the candidate will have at least **V** voting power after joining the validator set, they can enter.

## Implementation

We suggest setting **V** = 3 to minimize behavior change w.r.t the existing Sui staking implementation. Today’s scheme has three parameters:

* `min_validator_joining_stake`: the minimum stake threshold required to enter the validator set (note: this is roughly equivalent to **V**)
* `validator_low_stake_threshold`: a stake threshold below which the validator is on “probation” and will be removed from the validator set if they remain below this level for more than 7 consecutive epochs
* `validator_very_low_stake_threshold`: a stake threshold below which the validator is immediately removed from the validator set (at the next epoch change).

These parameters are all interpreted as absolute SUI amounts, and are currently set as follows:

* `min_validator_joining_stake`: 30M SUI
* `validator_low_stake_threshold`: 20M SUI
* `validator_very_low_stake_threshold`: 15M SUI

To preserve the behavior of the existing scheme and ratios (which were chosen carefully and are well tested) as much as possible, we propose to reinterpret these parameters as voting power thresholds with the following values:

- `min_validator_joining_stake`: 3 voting power
    - According to the formula above, this means that a validator must have ≥ 3 voting power to join the validator set
- `validator_low_stake_threshold`: 2 voting power
    - This means that a validator can remain indefinitely with a voting power ≥ 2. But as soon as the validator’s voting power falls to 1, they are on probation and must acquire sufficient stake to recover to voting power ≥ 2 within 7 epochs.
- `validator_very_low_stake_threshold`: 1 voting power
    - This means that a validator with voting power 0 will be removed from the validator set. To be precise, at the end of an epoch when new voting powers are computed based on stake changes, any validator with 0 voting power will be removed.

## Backward compatibility

To minimize churn and onboard new validators slowly, we propose gradually approaching the final voting power-based limits described above via the following sequence of phases for (`min_validator_joining_stake`, `validator_low_stake_threshold`, `validator_very_low_stake_threshold`):

- Phase 1: 12, 8, 4
- Phase 2: 6, 4, 2
- Phase 3: 3, 2, 1

We suggest a two week gap between each phase. This can be implemented in a single protocol upgrade that hardcodes the phase schedule.

The lowest voting power of any Sui validator today is 26, so phase 1 will not affect any existing validators.

With the total amount staked as of 8/11/24, 1 voting power "costs" ~800K SUI. Under the new proposal, entering the validator set would now require ~2.4M SUI, a substantially lower total than the current 30M minimum. Over time, perhaps the low stake and very low stake thresholds can be phased out altogether in favor of making the admission criteria as permissive as possible (1 voting power).

## Reference Implementation

https://github.com/MystenLabs/sui/pull/19836

## Copyright

[CC0 1.0](../LICENSE.md).
