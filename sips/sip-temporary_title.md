|   SIP-Number | |
|         ---: | :--- |
|        Title | On-Chain Liveness Oracle |
|  Description | Introduces a sui::checkpoint module that acts as a trustless liveness oracle, enabling on-chain circuit breakers. |
|       Author | Greshamscode, @92GC |
|       Editor | <Leave this blank; it will be assigned by a SIP Editor> |
|         Type | Standard |
|     Category | Framework |
|      Created | 2025-06-25 |
| Comments-URI | |
|       Status | |
|     Requires | |

## Abstract

This proposal introduces a new, read-only system module, sui::checkpoint, that functions as a native liveness oracle. It exposes historical checkpoint data and a highly efficient function to get the largest time gap between consecutive checkpoints in a recent history window. This enables smart contracts to detect network stalls and act as trustless circuit breakers, removing the need for off-chain social consensus on network health.

## Motivation

Currently, there is no way for a smart contract to programmatically determine if the Sui network has recently experienced significant downtime or a stall. This forces critical decisions about network health to rely on off-chain social consensus. This proposal introduces an on-chain, trustless liveness oracle. By providing a direct way to measure the largest time gap between recent checkpoints, it allows contracts to build in their own circuit breakers. TWAP functions should not be trusted if the chain has experienced significant down time. [Govex.ai](https://www.govex.ai/) a futarchy based DAO management platform on Sui would like to run it's TWAP over short time markets but does not want to risk a chain restart occuring during a short market, nor does it want to trust an admin with the power to invalidate markets.

## Specification

This SIP introduces a new native module, sui::checkpoint, with the following public functions:move
module sui::checkpoint {
```
module sui::checkpoint 
    /// Returns the sequence number of the most recently finalized checkpoint.
    public native fun last_finalized_sequence_number(): u64;

    /// Returns the consensus timestamp in milliseconds for the checkpoint with the
    /// given `sequence_number`.
    /// Returns `Some(timestamp)` if the checkpoint is within the protocol-defined
    /// accessible history window, and `None` otherwise.
    public native fun get_timestamp_ms(sequence_number: u64): option::Option<u64>;

    /// Returns the sequence number of the oldest checkpoint available via `get_timestamp_ms`.
    /// This allows contracts to discover the bounds of accessible history.
    public native fun accessible_history_window_start(): u64;

    /// Returns the largest time gap in milliseconds between any two consecutive
    /// checkpoints within the defined history window. This serves as a direct
    /// measure of recent network instability.
    public native fun largest_checkpoint_gap_in_history_window(): u64;

    /// Returns the largest time gap in milliseconds between any two consecutive
    /// checkpoints `(Ck, Ck+1)` where `Ck.sequence_number >= start_sequence_number`
    /// and `Ck+1.sequence_number <= last_finalized_sequence_number()`.
    ///
    /// - If `start_sequence_number` is less than `accessible_history_window_start()`,
    ///   this function returns `None` as the requested start is too old.
    /// - If `start_sequence_number` is greater than `last_finalized_sequence_number()`,
    ///   this function returns `None` as the start is invalid (e.g. in the future).
    /// - If `start_sequence_number` is equal to `last_finalized_sequence_number()`,
    ///   no gaps can be formed, so it returns `Some(0)`.
    /// - Otherwise, it iterates through the relevant checkpoints, calculates all
    ///   gaps `(timestamp(i+1) - timestamp(i))` for `i` from `start_sequence_number`
    ///   to `last_finalized_sequence_number() - 1`, and returns `Some(max_gap)`.
    ///   If any `get_timestamp_ms` call within the valid range unexpectedly returns `None`
    ///   (which shouldn't happen for finalized, accessible checkpoints), this function
    ///   would propagate the `None` or handle it as an internal error (implementation detail,
    ///   but `None` is safer for the caller).
    public native fun largest_checkpoint_gap_since_sequence_number(start_sequence_number: u64): option::Option<u64>;

```

## Rationale

This functionality must be implemented as a native module within the Sui runtime. The Move VM's security model prohibits smart contracts from arbitrarily accessing the ledger's historical state.

The functions `get_timestamp_ms` and `last_finalized_sequence_number` are simple lookups into the node's existing checkpoint database.

The `largest_checkpoint_gap_in_history_window` function, while seemingly complex, can be implemented with extreme efficiency at the native level using a "Sliding Window Maximum" algorithm. Instead of re-scanning millions of checkpoints, a validator maintains a specialized data structure (a double-ended queue) that tracks the largest gap. When a new checkpoint is added, only a few constant-time operations are needed to update this structure. Because older, smaller gaps can never become the maximum as the window slides forward, they are efficiently discarded from consideration. This ensures the largest gap is always pre-calculated and can be read instantly, making the function call fast and gas-efficient for smart contracts. The largest_checkpoint_gap_since_sequence_number(start_sequence_number: u64) function provides a more granular query. As it operates on a user-defined start point up to the present, it cannot rely on the same global pre-computation. Instead, it performs a linear scan over the requested checkpoint range [start_sequence_number, last_finalized_sequence_number()]. The computational cost is therefore proportional to the length of this range. Gas fees for this function will scale accordingly to prevent abuse."

## Backwards Compatibility

This proposal is a purely additive and non-breaking change. It introduces a new, self-contained module and does not alter any existing modules, functions, or data structures. No existing smart contracts will be affected.

## Test Cases

To be developed following initial review of the proposal.

## Reference Implementation

A reference implementation will be developed by core engineers if the SIP is approved.

## Security Considerations

1.  **Denial-of-Service (DoS) via Resource Exhaustion:** A malicious actor could repeatedly call `get_timestamp_ms` for old checkpoints, consuming excessive validator resources.
    *   **Mitigation:** The gas cost for `get_timestamp_ms` must include a variable component that scales with the age of the requested checkpoint (`current_checkpoint - requested_checkpoint`), making deep historical queries economically infeasible for attackers.
2.  **Validator State Bloat:** Requiring validators to store an infinite history of checkpoint metadata is unsustainable and would increase centralization pressure.
    *   **Mitigation:** The protocol must define and enforce a fixed-size, sliding window for the on-chain accessible history (e.g., the last 2-4 million checkpoints). Data older than this window would be pruned and only accessible via off-chain archival solutions.
3.  **Algorithmic Complexity of `largest_checkpoint_gap_in_history_window`:** A naive implementation of this function could be computationally expensive, creating a DoS vector.
    *   **Mitigation:** The native implementation must use an efficient sliding window algorithm (e.g., using a deque) as described in the Rationale. This ensures the calculation is near-constant time and does not create a computational bottleneck for validators.
4.  **Algorithmic Complexity of `largest_checkpoint_gap_since_sequence_number`:** This function performs a scan proportional to the number of checkpoints requested (N = last_finalized_sequence_number - start_sequence_number). A very large N could lead to high resource consumption.
    *   **Mitigation:** Implementing `largest_checkpoint_gap_since_sequence_number`natively as a Segment Tree for O(log W)  complexity.

## Copyright

Greshamscode 2025
