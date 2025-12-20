|   SIP-Number | <Leave this blank; it will be assigned by a SIP Editor> |
|         ---: | :--- |
|        Title | revert SIP-45 |
|  Description | revert SIP-45 deterministic consensus transaction ordering |
|       Author | moonshiesty<@moonshiesty> |
|       Editor | <Leave this blank; it will be assigned by a SIP Editor> |
|         Type | Standard |
|     Category | Core |
|      Created | 2025-02-23 |
| Comments-URI | <Leave this blank; it will be assigned by a SIP Editor> |
|       Status | <Leave this blank; it will be assigned by a SIP Editor> |
|     Requires | <Optional; SIP number(s), comma separated> |

## Abstract

Revert deterministic transaction ordering for consensus as implemented in SIP-45

## Motivation

SIP-45 does not achieve it's goals of prioritizing transaction-submission and instead provides a deterministic mechanism for searchers to position their transactions within a consensus checkpoint by manipulating gas price

for example SIP-45 allows a searcher to construct a sandwich by paying +1 of the target gas price on the frontrun and -1 unit SUI of the target gas price on the backrun. this is the optimal strategy for any searcher.

for backruns SIP-45 also does not maximize value for validators since it will always be optimial for searchers to pay exactly -1 unit of SUI to be ordered right after the target

for arbitrage SIP-45 does maximize validator value, at the risk of providing yet another mechanism for arbitragers themselves to be deterministically frontrun


## Specification

Revert SIP-45 and begin exploring of one of two approaches:

1) make consensus ordering random. sui randomness already provides a seed to randomly reorder transactions within consensus checkpoints. this approach likely requires an additional hop to consensus (+~130ms). this attempts to minimize extractable value by making it non-deterministic for searchers to place a transaction within a consensus checkpoint. the primary concern with this approach is that searchers can attempt to statistically frontrun targets by spamming transactions that revert if they don't land in the right spot

2) allow validators to specify consensus ordering and expose an API for searchers to propose a consensus ordering. this approach will maximize extractable value for validators and provides the equivalent of a ["block-building"](https://github.com/ethereum/builder-specs?tab=readme-ov-file) API on SUI

## Rationale

reverting SIP-45 is an important issue because deterministic consensus transaction ordering exposes users to MEV without a way to protect themselves through fee markets

front-running on SUI is possible whenever either:

1) protocol leaks information about transactions
2) a validator leaks information about transaction certification

because shio is leaking user transactions, this is present concern to SUI users

[source from author's X profile](https://x.com/moon_shiesty/status/1893783038653571292)

## Backwards Compatibility

no issues with backwards compatibility

## Security Considerations

none
