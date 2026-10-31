|   SIP-Number | 78 |
|         ---: | :--- |
|        Title | Sub-Epoch Transaction Expiry |
|  Description | Enables the `min_timestamp` and `max_timestamp` fields of `TransactionExpiration`, letting a transaction expire at a millisecond timestamp instead of an epoch boundary |
|       Author | Kevin \<github@aftermath.finance, @admin-aftermath\>, Aftermath Finance \<[aftermath.finance](https://aftermath.finance/)\> |
|       Editor | TBD |
|         Type | Standard |
|     Category | Core |
|      Created | 2026-10-28 |
| Comments-URI | TBD |
|       Status | Draft |
|     Requires | N/A |

## Abstract

This SIP proposes enabling timestamp-based transaction expiry on Sui. Today the shortest expiry a transaction can set is the end of the current epoch, and mainnet epochs last about 24 hours. The `ValidDuring` and `Validity` variants of `TransactionExpiration` carry `min_timestamp` and `max_timestamp` fields, but validators reject any transaction that sets them. This SIP defines what those fields mean, how validators enforce them, and the protocol flag that turns them on.

This matters most for latency-sensitive flows, such as signed quotes, market orders, and sponsored transactions, where a signature should expire within seconds. Validators measure a transaction's validity window against the timestamp of the consensus commit that sequences it, the same value Move code reads from `Clock`. The SIP adds no enum variant or field, so the BCS encoding of transactions stays the same.

> As Sui will continue to evolve over time, a snapshot of the Sui repo will be used when referencing Sui code. This SIP uses the latest stable version of mainnet: `mainnet-v1.82.3`.<sup>[1](https://github.com/MystenLabs/sui/tree/bf4073918ed33cfa0b09c500658fa116a774bcfd)</sup>

## Background

**Transaction Expiration.** Every `TransactionDataV1` carries a `TransactionExpiration`.<sup>[2](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-types/src/transaction.rs#L2427-L2474)</sup> `None` never expires, and `Epoch(e)` expires once the network passes epoch `e`. `ValidDuring` arrived with gas payments from address balances: it bounds a transaction to one or two epochs and adds a chain identifier and a nonce, which gives replay protection without a gas coin. `Validity` adds an `allowed_proposers` set on top of `ValidDuring`, as part of SIP-45.<sup>[3](https://github.com/sui-foundation/sips/blob/main/sips/sip-45.md)</sup>

```Rust
pub enum TransactionExpiration {
    /// The transaction has no expiration
    None,
    /// Validators wont sign a transaction unless the expiration Epoch
    /// is greater than or equal to the current epoch
    Epoch(EpochId),
    ValidDuring {
        /// Transaction invalid before this epoch. Must equal current epoch.
        min_epoch: Option<EpochId>,
        /// Transaction expires after this epoch. Must equal current epoch
        max_epoch: Option<EpochId>,
        /// Future support for sub-epoch timing (not yet implemented)
        min_timestamp: Option<u64>,
        /// Future support for sub-epoch timing (not yet implemented)
        max_timestamp: Option<u64>,
        /// Network identifier to prevent cross-chain replay
        chain: ChainIdentifier,
        /// User-provided uniqueness identifier to differentiate otherwise identical transactions
        nonce: u32,
    },
    Validity {
        min_epoch: Option<EpochId>,
        max_epoch: Option<EpochId>,
        /// Future support for sub-epoch timing (not yet implemented)
        min_timestamp: Option<u64>,
        /// Future support for sub-epoch timing (not yet implemented)
        max_timestamp: Option<u64>,
        chain: ChainIdentifier,
        nonce: u32,
        allowed_proposers: Option<AllowedProposers>,
    },
}
```

**Rejection.** `TransactionData::validity_check` rejects any transaction that sets either timestamp:<sup>[4](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-types/src/transaction.rs#L3516-L3521)</sup>

```Rust
if min_timestamp.is_some() || max_timestamp.is_some() {
    return Err(UserInputError::Unsupported(
        "Timestamp-based transaction expiration is not yet supported".to_string(),
    )
    .into());
}
```

&nbsp;&nbsp;&nbsp;&nbsp; The gRPC API treats both fields as milliseconds and converts them with `ms_to_timestamp` and `timestamp_to_ms`.<sup>[5](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-types/src/rpc_proto_conversions.rs#L2338-L2339)</sup>

**Expiry Checks.** Validators check epoch expiry before consensus. `validity_check` runs when a validator receives a transaction (`handle_submit_transaction_inner`) and when it votes on a block another validator proposed (`vote_transaction`).<sup>[6](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-core/src/consensus_validator.rs#L295-L309)</sup> Its context, `TxValidityCheckContext`, holds the current epoch and no time.<sup>[7](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-types/src/transaction.rs#L4000-L4007)</sup> The epoch cannot change while a transaction sits in consensus, so one check before consensus covers epoch expiry. Time keeps moving during that wait, so a timestamp needs a second check after consensus.

&nbsp;&nbsp;&nbsp;&nbsp; Validators also re-run `validity_check` in `prepare_certificate`, before execution, and treat any error there as fatal.<sup>[8](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-core/src/authority.rs#L1949-L1954)</sup>

**Consensus Time.** Mysticeti assigns each commit a timestamp: the stake-weighted median of the timestamps of the leader's parent blocks, raised to the previous commit's timestamp when lower so that it never decreases.<sup>[9](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/consensus/core/src/linearizer.rs#L122-L156)</sup> The consensus handler clamps it to the epoch start time<sup>[10](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-core/src/consensus_handler.rs#L260-L290)</sup> and writes it into the commit's `ConsensusCommitPrologue`,<sup>[11](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-core/src/consensus_handler.rs#L362-L377)</sup> which sets the `Clock` object. Every validator sees the same commit timestamp.

**Dropping After Consensus.** `filter_consensus_txns` drops some sequenced transactions in a way every validator agrees on, for example when owned-object locks conflict. A dropped transaction gets `ConsensusTxStatus::Dropped` and a rejection reason, does not execute, and pays no gas.<sup>[12](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-core/src/consensus_handler.rs#L2859-L2881)</sup>

## Motivation

**Limitations.** When you sign a transaction today, the shortest expiry you can set is the end of the current epoch, up to 24 hours away on mainnet. Many transactions need a shorter life:
 1. **Sponsored + Gasless Transactions.** A sponsor co-signs a transaction and wants that signature to be usable for a short time. Address balances make this pressing. When a sponsor pays gas with a coin, the signature names a version of that coin, and the sponsor's next transaction with the coin invalidates it. When a sponsor pays from its address balance, the transaction names no gas object, so the sponsor's signature stays usable until `max_epoch` passes, which `ValidDuring` allows to be up to two epochs away.
 1. **Quotes + RFQs.** A market maker signs a fill at a price that is good for a few seconds.
 1. **Market Orders.** A user submits an order that should fill now or not at all.
 1. **Intents + Session Keys.** An app holds a user's signed transaction and should not be able to submit it hours later.

**Workarounds.** Today, protocols enforce deadlines by asserting on `Clock` inside Move:

```Move
assert!(clock.timestamp_ms() <= deadline_ms, EExpired);
```

&nbsp;&nbsp;&nbsp;&nbsp; This approach has drawbacks:
 1. The transaction still goes through consensus and execution, and you pay gas for the abort.
 1. Every such transaction takes the shared `Clock` as an input.
 1. Each protocol writes and audits its own deadline check, which wallets cannot see or explain to users.

**Sub-Epoch Expiry.** With this SIP, validators drop an expired transaction before it executes. You pay no gas, the transaction does not need `Clock`, and wallets can read the deadline from the transaction and show it before you sign.

&nbsp;&nbsp;&nbsp;&nbsp; Aftermath would set a deadline on the transactions it sponsors from its address balance, such as One-Click Trading, so nobody can submit a sponsored signature after its session ends. Aftermath would also use this for perpetuals market orders, limit-order fills, and signed quotes.

## Prerequisites

There are no prerequisites for this SIP. The fields this SIP enables already exist in `ValidDuring` and `Validity`.

## Specification

**Units.** `min_timestamp` and `max_timestamp` are Unix timestamps in milliseconds, matching the gRPC API and `Clock::timestamp_ms`.

**Validity Window.** Let `T` be the timestamp of the consensus commit that sequences a transaction. The transaction is valid only if:
 1. `min_timestamp` is unset, or `min_timestamp <= T`, and
 1. `max_timestamp` is unset, or `T <= max_timestamp`.

&nbsp;&nbsp;&nbsp;&nbsp; Both bounds are inclusive. The epoch bounds still apply, and a transaction must satisfy both.

**Static Checks.** `validity_check` accepts either timestamp when `enable_timestamp_transaction_expiration` is on, and rejects `min_timestamp > max_timestamp` when both are set. It makes no comparison against the current time. `validity_check` runs again in `prepare_certificate` and fails fatally there, so any check that depends on time would halt execution of a transaction that was valid when sequenced.

**Signing Checks.** A new `TransactionData::check_timestamp_window(now_ms)` rejects a transaction whose window has closed (`max_timestamp < now_ms`) or has not opened (`min_timestamp > now_ms`). Validators run it with their local clock when they receive a transaction and when they vote on a block. Clients should submit a transaction at or after its `min_timestamp`.

&nbsp;&nbsp;&nbsp;&nbsp; This check decides nothing on its own. It returns a fast error to clients and keeps stale transactions from taking up consensus bandwidth, so validators do not need to agree on its result, and a transaction that passes it can still expire in consensus. For the same reason, the check is local validator behavior and takes no protocol config parameter. If operators want a tolerance for clock error or a margin for sequencing latency, Sui can add one to the node config without a protocol upgrade.

**Consensus Check.** In `filter_consensus_txns`, before acquiring owned-object locks, validators drop any user transaction whose validity window does not contain the commit timestamp. A dropped transaction gets:
 1. `ConsensusTxStatus::Dropped`,
 1. `TransactionExpired` as its rejection reason, which clients treat as final, and
 1. no execution and no gas charge.

&nbsp;&nbsp;&nbsp;&nbsp; This check is final. Every validator computes it from the same commit timestamp, so every validator drops the same transactions.

**Deferred Transactions.** Validators check the window once, in the commit that first sequences the transaction. Congestion control or randomness can defer a transaction to a later commit, and validators execute it then even if its `max_timestamp` has passed. `max_timestamp` sets a sequencing deadline. Deferral is bounded by `max_deferral_rounds_for_congestion_control`, after which validators cancel the transaction.<sup>[13](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-core/src/authority/transaction_deferral.rs#L83-L98)</sup> Protocols that need a hard execution deadline can keep their `Clock` assertion.

**Replay Protection.** This SIP does not change replay protection. Timestamps only narrow a window that the epoch bounds define, so `is_replay_protected`<sup>[14](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-types/src/transaction.rs#L2500-L2518)</sup> and `check_replay_protection` stay as they are.

**Protocol Config.** A new feature flag, `enable_timestamp_transaction_expiration`, gates the static check, the signing check, and the consensus check. While it is off, validators keep rejecting any transaction that sets a timestamp.

## Rationale

**Reusing the Existing Fields.** The fields have been established since `ValidDuring` shipped, and the gRPC API encodes them. Enabling them changes no type, so SDKs that build `ValidDuring` or `Validity` transactions only need to expose two optional values.

**Commit Timestamp.** Validators need a time they all agree on, and the commit timestamp is the only one. It is the median by stake, so validators with bad clocks holding less than a third of stake cannot move it outside the range the honest validators report. It never decreases. It is the value Move code already sees through `Clock`, so a deadline in the transaction and a deadline in Move mean the same thing.

**Dropping Instead of Aborting.** An expired transaction could instead execute and fail with a new execution error. That would charge gas for a transaction the sender asked never to run, and it would add a variant to `ExecutionFailureStatus`, which changes the effects format. Dropping reuses a path that already exists and changes no on-chain data.

**Checking at First Sequencing.** Re-checking deferred transactions would need a new cancellation reason in transaction effects. Checking once keeps the change inside the consensus handler, and the deferral bound limits how late a deferred transaction can run.

**Keeping the Epoch Bounds.** A timestamp-only window would need validators to remember executed digests for as long as the window lasts. Requiring `min_epoch` and `max_epoch` keeps the replay model that `ValidDuring` already uses.

## Backwards Compatibility

**Existing Transactions.** Validators reject every transaction that sets a timestamp today, so no existing transaction changes meaning. `None`, `Epoch`, and `ValidDuring` / `Validity` without timestamps behave as before.

**Validators.** The consensus check changes which transactions execute, so every validator must apply it from the same protocol version. The flag gates it, following `allowed_proposers`, which went to devnet in protocol version 136 and to testnet and mainnet in 137.<sup>[15](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-protocol-config/src/lib.rs#L390-L407)</sup>

**Ecosystem.** SDKs, `sui client`, wallets, explorers, and indexers should expose `min_timestamp` and `max_timestamp`, show the deadline before the user signs, and treat a `TransactionExpired` drop as final. Client retry logic must not resubmit an expired transaction.

## Reference Implementation

This SIP changes `sui-types`, `sui-core`, and `sui-protocol-config`. `...` marks unchanged code.

### i. `crates/sui-types/src/transaction.rs`

#### ia. Static checks in `validity_check`

Replace the unconditional rejection:

```Rust
if min_timestamp.is_some() || max_timestamp.is_some() {
    fp_ensure!(
        config.enable_timestamp_transaction_expiration(),
        UserInputError::Unsupported(
            "Timestamp-based transaction expiration is not yet supported".to_string(),
        )
        .into()
    );
    if let (Some(min), Some(max)) = (min_timestamp, max_timestamp) {
        fp_ensure!(
            min <= max,
            UserInputError::InvalidExpiration {
                error: "min_timestamp must not exceed max_timestamp".to_string(),
            }
            .into()
        );
    }
}
```

#### ib. Window helpers on `TransactionExpiration`

```Rust
impl TransactionExpiration {
    ...

    /// The `(min_timestamp, max_timestamp)` bounds in milliseconds, if any.
    pub fn timestamp_bounds(&self) -> (Option<u64>, Option<u64>) {
        match self {
            TransactionExpiration::ValidDuring {
                min_timestamp,
                max_timestamp,
                ..
            }
            | TransactionExpiration::Validity {
                min_timestamp,
                max_timestamp,
                ..
            } => (*min_timestamp, *max_timestamp),
            _ => (None, None),
        }
    }

    /// Whether a transaction sequenced at `timestamp_ms` falls inside its window.
    pub fn is_valid_at_timestamp(&self, timestamp_ms: u64) -> bool {
        let (min, max) = self.timestamp_bounds();
        min.is_none_or(|min| min <= timestamp_ms) && max.is_none_or(|max| timestamp_ms <= max)
    }
}
```

#### ic. Signing check on `TransactionData`

```Rust
impl TransactionData {
    ...

    /// Rejects a transaction whose window has closed or has not opened.
    /// Uses the validator's local clock, so validators need not agree on the result.
    /// Must not run from `validity_check`, which `prepare_certificate` re-runs before execution.
    pub fn check_timestamp_window(&self, now_ms: u64) -> SuiResult {
        if !self.expiration().is_valid_at_timestamp(now_ms) {
            return Err(SuiErrorKind::TransactionExpired.into());
        }
        Ok(())
    }
}
```

&nbsp;&nbsp;&nbsp;&nbsp; This change also removes the "Future support for sub-epoch timing (not yet implemented)" comments from both variants and documents the fields as Unix milliseconds.

### ii. `crates/sui-core/src/authority_server.rs` + `crates/sui-core/src/consensus_validator.rs`

Run the signing check next to the existing `validity_check` calls in `handle_submit_transaction_inner` and `vote_transaction`:

```Rust
transaction.validity_check(&epoch_store.tx_validity_check_context())?;

if epoch_store
    .protocol_config()
    .enable_timestamp_transaction_expiration()
{
    transaction.transaction_data().check_timestamp_window(
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("system time is after the Unix epoch")
            .as_millis() as u64,
    )?;
}
```

### iii. `crates/sui-core/src/consensus_handler.rs`

In `filter_consensus_txns`, before the post-consensus owned-object conflict detection:

```Rust
if let ConsensusTransactionKind::UserTransactionV2(tx_with_claims) =
    &parsed.transaction.kind
    && self
        .epoch_store
        .protocol_config()
        .enable_timestamp_transaction_expiration()
    && !tx_with_claims
        .tx()
        .transaction_data()
        .expiration()
        .is_valid_at_timestamp(commit_info.timestamp)
{
    // Deterministic drop: every validator compares against the same commit timestamp.
    self.metrics
        .consensus_handler_dropped_transactions
        .with_label_values(&["expired"])
        .inc();
    status_updates.push((position, ConsensusTxStatus::Dropped));
    num_dropped_user_transactions[author] += 1;
    self.epoch_store
        .set_rejection_vote_reason(position, &SuiErrorKind::TransactionExpired.into());
    dropped_transaction_keys.push(parsed.transaction.key());
    continue;
}

// Perform post-consensus owned object conflict detection.
...
```

### iv. `crates/sui-protocol-config/src/lib.rs`

```Rust
// If true, `min_timestamp` and `max_timestamp` in `ValidDuring` and `Validity` expirations
// are accepted and enforced against the consensus commit timestamp.
#[serde(skip_serializing_if = "is_false")]
enable_timestamp_transaction_expiration: bool,
```

Following precedent, Mysten enables the flag on devnet first, then testnet, then mainnet, each in a later protocol version.

## Security Considerations

**Free Drops.** A dropped transaction uses consensus bandwidth and pays no gas. Existing drop reasons have the same cost. The signing check keeps expired and not-yet-open transactions out of consensus, so an attacker gets a free drop by timing a transaction to expire while it sits in consensus, at the cost of one valid signature per attempt. Validators can extend the existing per-submitter spam weighting to expired drops.

**Clock Manipulation.** The commit timestamp is a stake-weighted median, so validators holding less than a third of stake cannot push it outside the range honest validators report. It never decreases within an epoch. A Byzantine supermajority could move it, but such a supermajority can already censor or reorder transactions.

**Fatal Re-Checks.** `prepare_certificate` re-runs `validity_check` and fails fatally on error. The time comparison must stay out of `validity_check`; otherwise a transaction sequenced inside its window would halt execution on any validator or full node whose clock reads later.

**Replay.** If validators drop a transaction because its window has not opened, the sender can resubmit it once the window opens, as intended. A transaction dropped for expiring can never become valid again, because the commit timestamp never decreases. Once a transaction executes, the existing epoch-based replay protection applies.

**Deferral.** A deferred transaction can execute after its `max_timestamp`, up to the deferral bound. The specification states this, and protocols that need a hard execution deadline can keep their `Clock` assertion.

**Epoch Boundaries.** A window that crosses an epoch boundary is still bounded by `max_epoch`. A transaction that does not execute before reconfiguration follows the existing end-of-epoch rules.

## References

1. [[Sui Repo] mainnet-v1.82.3](https://github.com/MystenLabs/sui/tree/bf4073918ed33cfa0b09c500658fa116a774bcfd)
1. [[Sui Repo] `TransactionExpiration`](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-types/src/transaction.rs#L2427-L2474)
1. [[SIPs] SIP-45: Prioritized Transaction Submission](https://github.com/sui-foundation/sips/blob/main/sips/sip-45.md)
1. [[Sui Repo] Timestamp expiration rejection](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-types/src/transaction.rs#L3516-L3521)
1. [[Sui Repo] gRPC timestamp conversion](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-types/src/rpc_proto_conversions.rs#L2338-L2339)
1. [[Sui Repo] `SuiTxValidator::vote_transaction`](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-core/src/consensus_validator.rs#L295-L309)
1. [[Sui Repo] `TxValidityCheckContext`](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-types/src/transaction.rs#L4000-L4007)
1. [[Sui Repo] `prepare_certificate` validity re-check](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-core/src/authority.rs#L1949-L1954)
1. [[Sui Repo] Commit timestamp calculation](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/consensus/core/src/linearizer.rs#L122-L156)
1. [[Sui Repo] `ConsensusCommitInfo` timestamp clamp](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-core/src/consensus_handler.rs#L260-L290)
1. [[Sui Repo] `ConsensusCommitPrologueV4` timestamp](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-core/src/consensus_handler.rs#L362-L377)
1. [[Sui Repo] Post-consensus transaction drops](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-core/src/consensus_handler.rs#L2859-L2881)
1. [[Sui Repo] Deferral limit](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-core/src/authority/transaction_deferral.rs#L83-L98)
1. [[Sui Repo] `TransactionExpiration::is_replay_protected`](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-types/src/transaction.rs#L2500-L2518)
1. [[Sui Repo] `allowed_proposers` rollout](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-protocol-config/src/lib.rs#L390-L407)

## Copyright

[CC0 1.0](../LICENSE.md).
