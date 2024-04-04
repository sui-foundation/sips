|   SIP-Number | 100                                                  |
| -----------: | :--------------------------------------------------- |
|        Title | Soft Bundle API                                      |
|  Description | Add the soft bundle API to the Sui Authority Server. |
|       Author | Shio Coder <shio.coder@gmail.com>                    |
|       Editor | Will Riches <will@sui.io, @wriches>                  |
|         Type | Standard                                             |
|     Category | Core                                                 |
|      Created | 2024-04-05                                           |
| Comments-URI | https://sips.sui.io/comments-100                     |
|       Status | Draft                                                |
|     Requires | N/A                                                  |

## Abstract

This SIP introduces a Soft Bundle API to the Authority Server.

## Motivation

While PTB is a great way to bundle transactions, it is not suitable for sequencing transactions with different signers.
In addition, it does not allow partial reverts (e.g., a subset of the transactions in the PTB reverts). The Soft Bundle API is a way to bundle transactions with different signers and sequence them (and allow partial revert) in a single bundle with a high probability.

## Specification

Implement a new Grpc method `HandleSoftBundleCertificatesV2` in AuthorityServer, that accepts and executes a vector of certificates, ensuring:

- If at least one certificate cannot be executed, the whole request is denied.
- If at least one certificate has already been executed, the whole request is denied.
- If at least one certificate contains only owned object, the whole request is denied.
- If at least one certificate has a different gas price than others, the whole request is denied.
- If the number of certificates exceeds `N` , the whole request is denied.
  N should be small enough, say `N = 4`.
- If the total number of BCS serialized bytes from all certificates exceeds M bytes, the whole request is denied. M should be small enough, say `M = 64K`.

The method submits certificates from the same bundle to consensus altogether, without delay.
Submission will be through the same Narwhal worker, in the same Batch that is broadcasted to all other workers on the network.
This requires modification to consensus client (ConsensusAdapter) as well as Narwhal’s BatchMaker, so that they accept a vector of certificates as input.

After including the bundle in the same Batch, we can be certain that if this Batch is getting included in a Header in consensus, its internal ordering will be respected.
Meanwhile:

- Since all certificates may not contain only owned objects, their relative order is determined by consensus.
- PostConsensusTxReorder does not affect this because all transaction blocks in the same bundle have identical gas prices.

The response type of the method will be:

```Rust
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct HandleSoftBundleCertificatesResponseV2 {
    pub responses: Vec<HandleCertificateResponseV2>,
}
```

## Rationality

In the current implementation of Sui, transaction blocks are validated, signed, and then submitted for consensus ordering (since their input contains one or more contains one or more shared objects), most likely by different validators. The ordering of transaction blocks, given the same gas price, depends on many factors that cannot be easily controlled.

Although SenderSignedData is a vector, its usage pattern today does not allow the extension to support bundling primitives without significant refactoring effort. Since one of the design principles is to avoid major system changes, we propose the Soft Bundle API, an approach that makes minimal changes while ensuring strong enough bundling semantics in most cases.

Note that the Soft Bundle API does not provide a strict ordering guarantee. However, it does provide an extremely high probability of being ordered correctly. The effort and maintenance costs of a strict guarantee are very high, and may conflict with core Consensus design principles and development schedules. We believe that the Soft Bundle API is a good enough for most use cases.

The post-consensus reordering mechanism would not affect the soft bundle API at this time, but we acknowledge that it may be a potential issue in the future. We will need to monitor the situation and make changes if necessary.

## Backwards Compatibility

There are no issues with backwards compatability.

## Reference Implementation

[Commit](https://github.com/shio-coder/sui/commit/b12ae55852709084263e23e33f3446c6bf62550e)

TODO: Add unit tests

## Security Considerations


### Front-running

It is possible that order originators (e.g., full nodes) could attack users by front-running their transactions.

However, this is already possible today, even without Soft Bundle support, by simply submitting a carefully crafted front-running transaction before the user. We acknowledge that the Soft Bundle API makes the attack even easier. However, we believe that there is no fundamental difference between the two and that the Soft Bundle API does not introduce any new security risks.

To mitigate the risk, we will need to add audit logging to the Soft Bundle API so that we can detect and respond to any attacks and advise users not to submit transactions to the malicious order originators.


### Consensus Amplification

In the current design of consensus, a signed transaction block will not be submitted by all validators at the same time, but only a small subset of the validators.
With Soft Bundle API, however, a new attack vector could be introduced that effectively amplifying consensus traffic, as a validator that handles a soft bundle will need to submit the transaction blocks to consensus immediately.

A malicious actor may deliberately submit the same soft bundle to all validators that has enabled the feature, causing all validators to submit the same transaction blocks to consensus at the same time.

To address the issue, we propose:
- In the current implementation, a submit delay is already computed for each transaction block.
- Applying the same submit delay on the entire submission of the soft bundle, based on its first transaction block, as if we are not looking at a whole bundle but rather a single transaction block.
- The submit delay applies on the entire bundle bundle, and all transaction blocks in the same bundle are still later submitted together.

This will effectively reduce the amplification to the same level as the current design does, therefore mitigating the risk.

### Locked Owned Object

If one client has asked the majority of validators to sign a transaction block, but later get rejected by Soft Bundle API, its owned objects will be locked until the epoch.
This is, however, not a new issue raised from implementing the new API - but a pre-existing one, as a client from today could get a transaction block signed by validators, then decided (or by accident) not to submit it.

We acknowledge this risk and propose that:
- Clients should be aware of the risk and are responsible for eventually submitting all the certificates that are signed by validators.
- A new option could be added to Soft Bundle API, to allow a fallback where if the bundle is rejected, it will be submitted as if there is no bundling at all.


## Copyright

[CC0 1.0](../LICENSE.md).
