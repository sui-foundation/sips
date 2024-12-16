
| SIP-Number          | 45 |
| ---:                | :--- |
| Title               | Prioritized Transaction Submission |
| Description         | Enable effective prioritized transaction submission. |
| Author              | Shio Coder \<shio.coder@gmail.com\> |
| Editor              | Will Riches \<will@sui.io, @wriches\>
| Type                | Standard |
| Category            | Core |
| Created             | 2024-11-26 |
| Comments-URI        | https://sips.sui.io/comments-45 |
| Status              | Fast Track |
| Requires            | N/A |

## Abstract

Enable effective prioritized transaction submission based on gas price.

## Motivation

Currently, there is no deterministic gas ordering for the transactions, even when these transactions are submitted within an extremely short time window (less than 100ms). This is due to the fact that different transactions are randomly submitted by different validators, and the validator that is supposed to submit the transaction can have latency jitters. We propose a mechanism to mitigate the random factor and enable prioritized transaction submission.

## Specification

We propose the following changes:

- Increase the maximum allowed value of gas price from $99,999$ to $1,000,000,000,000$ (1T).
- Allow immediate transaction broadcast based on gas price.
  - Once a validator receives a transaction with a higher gas price, it is submitted immediately to consensus regardless of tx digest, with the least possible delay, if the validator is in the range of $[0, N)$ of submission position.
  - $N$ is a function of gas price, defined as:

    - if $`gas\_price < K \times RGP`$ then $N = 1$
    - else $`N = gas\_price / RGP + 1`$

We acknowledge that in order to adapt to the forthcoming Mysticeti Fast Path, further changes are needed.  

$K$ is a constant chosen to limit amplification. A smaller value of $K$ will increase amplification to the Sui network. In this case, $5$ is chosen as the initial value of $K$.

## Rationale

Transaction ordering on Sui depends on many factors that may or may not be within the control of the user.

Consider such a scenario where multiple actors are competing against one trading opportunity, where which transaction lands first wins. One actor may send a transaction, specifying the maximum possible gas price (99,999), hoping that the transaction will be included in the earliest possible position in the very next round of consensus commits. However, doing so will not reliably succeed. In fact, she may find out that despite paying the highest possible gas price, transaction inclusion still appears random, the effect of using a higher gas price is negligible.

We have located and analyzed multiple CEX-DEX trading bots and found no exception other than using a constant gas price (for example, 850 MIST), despite the fact that they are competing with each other.

As of today, there is little one can do about the case, other than submitting many different transactions that are further submitted by different validators, or simply resort to luck.

We believe one way to resolve this is to enable the user to send a tx with a even higher gas price (that comes with a significant real cost) should they choose to do so, while if the price paid is high enough, more validators will submit the transaction immediately, referencing its computed submission position from transaction’s digest. The higher gas price the user pays, the more validators will submit the transaction immediately. We have chosen the function of N so that a user has no incentive to send multiple transactions.

We have studied transactions in the past 30 days (as of 2024-11-07), a distribution of gas price as well as the projected effects from our proposal are shown as follows:

| Gas Price Bucket | Number of Txs | %      | $max(N)$ | `Amp%`   | `Cum Amp%` |
| ---------------: | :------------ | ------ | ------ | ------ | -------- |
| $[0, 5000)$        | 249058741     | 99.783 | 1      | 99.783 | 99.783   |
| $[5000, 10000)$    | 37872         | 0.015  | 14     | 0.212  | 99.996   |
| $[10000, 20000)$   | 303449        | 0.122  | 27     | 3.283  | 103.278  |
| $[20000, 30000)$   | 58921         | 0.024  | 40     | 0.944  | 104.222  |
| $[30000, 40000)$   | 5370          | 0.002  | 54     | 0.116  | 104.339  |
| $[40000, 50000)$   | 4128          | 0.002  | 67     | 0.111  | 104.449  |
| $[50000, 60000)$   | 9958          | 0.004  | 80     | 0.319  | 104.769  |
| $[60000, 70000)$   | 2818          | 0.001  | 94     | 0.106  | 104.875  |
| $[70000, 80000)$   | 3953          | 0.002  | 107    | 0.169  | 105.044  |
| $[80000, 90000)$   | 1729          | 0.001  | 120    | 0.083  | 105.127  |
| $[90000, 100000)$  | 112992        | 0.045  | 134    | 6.066  | 111.193  |

- `Amp%` represents the percentage of amplification from that bucket.
- `Cum Amp%` represents the cumulative % of amplification from that bucket and all preceding buckets.

From the data above, we predict that consensus bandwidth will be increased by no more than 12% should the proposal get implemented. In return, non-deterministic factors will become minimum, which makes actors able to compete by trying to outbid each other, where the participants will have to pay a much higher gas fee than before, in exchange for the certainty of reliably winning, should one outbid everyone else.

## Backwards Compatibility

The SIP introduces no incompatible changes.

## Security Considerations

None.
