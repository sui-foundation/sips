|   SIP-Number | <Leave this blank; it will be assigned by a SIP Editor> |
|         ---: | :--- |
|        Title | Block Streaming |
|  Description | Enable streaming uncommitted consensus blocks to full nodes. |
|       Author | Mingwei Tian <mingwei@mystenlabs.com, @mwtian> |
|       Editor | <Leave this blank; it will be assigned by a SIP Editor> |
|         Type | Standard |
|     Category | Core |
|      Created | 2025-02-25 |
| Comments-URI | <Leave this blank; it will be assigned by a SIP Editor> |
|       Status | <Leave this blank; it will be assigned by a SIP Editor> |
|     Requires | |

## Abstract

To further decrease the latency of propagating data in Sui, we propose allowing validators to stream
consensus blocks to full nodes. Full nodes with the feature enabled will run Mysticeti consensus to process
the incoming blocks, execute transactions before they are received via checkpoints, and create certified
checkpoints locally.

## Motivation

Currently Sui has 320-350ms p50 consensus latency and sub 700ms p50 e2e transaction settlement latency. But it can take longer for non validators to receive the latest transactions. The diagram below illustrates the common case:

![transaction_propagation](../assets/sip-block-streaming/transaction_propagation.png)

1. A transaction is included in consensus, for example in round 100 blocks.
1. A quorum of round 103 blocks commit the leader in round 101, which commits the majority of blocks in round 100 including the one containing the transaction.
    - Uncommon cases: Round 101 leader is skipped in round 102. Or round 101 leader is indirectly committed / skipped in a later round.
1. Checkpoint signatures can be created immediately after the round 103 commit, or 2~3 consensus rounds later because of checkpoint batching. The range would be round 104-106 in this example.
1. After checkpoint signatures are submitted to consensus, it takes another consensus round to propagate the signatures across validators and certify the checkpoint.

We can see there are places where the latency can be reduced, if full nodes can receive consensus blocks instead of certified checkpoints.
1. For information on settled transactions, full nodes can start executing transactions as soon as they are committed in consensus, instead of waiting for the certified checkpoints containing them to arrive. Basically the extra 2-4 consensus rounds or 150ms - 350ms of latency for certifying checkpoints can be eliminated.
1. Applications which can utilize optimistic knowledge of the transactions can process transactions as consensus blocks are received.

One example use case is for market markers who want to observe the latest transactions affecting a trading pair as soon as possible.

## Specification

Full nodes will have a new config flag to enable running Mysticeti consensus. Mysticeti will operate in a new mode on full nodes where no own block is proposed, and peers blocks are subscribed from only 1 peer instead of multiple of them.

### Network Config & Discovery

A new port (”consensus auxiliary”) will be added, to isolate validator consensus traffic from full node block stream subscribers. Access to the validator consensus port will still be restricted to validators. Validators will likely also restrict access to their consensus auxiliary ports to chosen state sync full nodes (SSFNs). SSFNs will open their consensus auxiliary ports to all full nodes. The existing state sync peer discovery implementation can be reused to discover the block stream publisher.

## Protocol

Connections will be initiated by the stream subscriber full node to the stream publisher, by sending over its highest accepted block per authority and highest commit reference. If the subscriber’s highest commit index lags behind the publisher’s, the subscriber can run commit sync with the publisher as peer to catchup quickly.

Since the subscriber does not provide details on which blocks it has locally, it is possible for the subscriber to receive published blocks that miss ancestors. So it is necessary to run block sync at the subscriber to synchronize blocks from the publisher as well. Alternatively, the subscriber can send all of its local block refs within GC round to the publisher first. Then missing ancestors on received blocks would indicate a faulty publisher, which warrants the subscriber to disconnect.

The stream publisher should keep track of blocks sent per authority to the subscriber, within the GC window. Only new blocks are sent by the publisher. Blocks are sent in batches, to reduce the number of messages sent.

## Rationale

The design tries to reuse as much of the existing Mysticeti consensus implementation as possible.

## Backwards Compatibility

The biggest compatibility concern is how this works together with the existing state sync protocol. The idea is only enable block streaming if the full node has the feature enabled and it is not lagging in epoch. Otherwise, state sync will run until the block stream subscriber catch up in epoch as the publishers.

## Security Considerations

The most significant security concern is on DDoS protection on SSFNs. We will rely on the existing DDoS protection mechanisms first, and potentially develop ways to bid for SSFN egress by subscribers in the future.

## Copyright

[CC0 1.0](../LICENSE.md).
