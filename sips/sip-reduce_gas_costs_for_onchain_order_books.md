|   SIP-Number | |
|         ---: | :--- |
|        Title | Reduce Gas Costs for Onchain Order Books |
|  Description | Reduce the non-refundable storage fee and the per-byte read charge for package inputs to 1% of their current values. |
|       Author | Mark Logan (@mystenmark) |
|       Editor | |
|         Type | Standard |
|     Category | Core |
|      Created | 2026-09-28 |
| Comments-URI | |
|       Status | |
|     Requires | |

## Abstract

The purpose of this SIP is to make it much cheaper to operate an on-chain orderbook. Because orderbooks require constant requoting by market makers, even small amounts of gas add up rapidly.

The cost reductions come from two places:

1. The non-refundable storage fee. The protocol keeps this fee from the storage rebate of every object that a transaction mutates or deletes. It is currently 1% of the rebate. This SIP lowers it to 0.01%.
2. The per-byte read charge for Move package inputs. The protocol charges this fee on the full size of every non-system package that a transaction calls. It is currently 15 internal gas units per byte. This SIP lowers it to 154 internal gas units per KiB (about 0.15 per byte).

Neither charge reflects a real cost born by validators today. The non-refundable storage fee was intended to pay for storage that is not reclaimed when objects are deleted. However, validators do not store any long-term data other than objects. Within an epoch, they must store transactions, effects, and other data. But since this data has a limited lifetime on the validators (that is, future validators are not burdened with work incurred by past validators), it can be paid for by computate charges.

## Motivation

### The non-refundable storage fee

When a transaction mutates an object, the protocol treats the old version as deleted. It then charges the new version the full storage cost. The sender receives `storage_rebate_rate` (currently 9900 basis points) of the old version's rebate. The protocol keeps the remaining 1% in the storage fund permanently.

As a result, the fee is a charge on each write, not a fixed share of the original deposit. Rewriting an object of storage cost `S` costs `0.01 × S` each time, even if its size does not change. The rebate stays at `S`. After 100 writes, the total non-refundable fees for an object equal its entire rebate, and they keep growing after that. Order books rewrite the same shared objects (the clearing house, order book leaves, and positions) on every order, so they pay this fee again and again.

The Sui tokenomics paper (May 2022, §5.1) gives the only rationale for this fee. It says that a rebate share `θ < 1` "is useful if some but not all the data associated with a transaction τ can be deleted and a share 1 − θ of the storage fees remain in the fund to compensate storage costs in perpetuity."

That condition does not hold on Sui today. Validators prune transactions, effects, events, and old object versions. The only data that validators keep permanently is the live object set, and the storage deposit on each live object already pays for it. No data remains after a deletion or a rewrite that the retained 1% would pay for.

### The package read charge

Before execution, the protocol charges each input object `obj_access_cost_read_per_byte` (15 internal gas units) per byte of its metered size. Every package that a transaction's `MoveCall` commands name, including packages that appear only in type arguments, counts as an input object. The charge skips system packages (`0x1`, `0x2`, `0x3`, and so on). The protocol charges the package's full size on every transaction, whether or not the validator already holds the package in memory.

Validators do not pay a per-transaction cost that grows with package size. Packages are immutable and validators cache them. While there may be some marginal cost associated with larger packages, it is negligible today. As a result, even a trivial function call (such as `fun identity<T>(f: T): T { f }`) into a large package can be quite expensive. Not only does this charge grossly inflate the cost of many transactions, it also makes it futile to optimize compute gas usage in most cases.

### Example transaction

Transaction `6RKMPxBY4AzQoD6aPqGDdkrm6D6Q3bFRJm58CeG3RLgJ` (mainnet, epoch 1264, protocol version 137) cancels orders and places two limit orders on an onchain perpetuals exchange. It pays a gas price of 100 MIST, which equals the reference gas price.

The transaction mutates six objects, and none of them changes size. The total storage deposit is 24,168,000 MIST both before and after. The six objects are:

| Object | Bytes | Rebate (MIST) |
|---|---:|---:|
| `ClearingHouse` | 1,156 | 8,785,600 |
| Order book leaf | 598 | 4,544,800 |
| Position | 550 | 4,180,000 |
| Order book leaf | 482 | 3,663,200 |
| Account | 264 | 2,006,400 |
| Gas coin | 130 | 988,000 |

The transaction reads 10 input objects with a total metered size of 107,970 bytes. Three of them are packages: the exchange package (100,922 bytes) and two packages named in type arguments (2,913 and 1,521 bytes). The transaction was replayed with the `sui replay` tool and its gas was measured with a Move execution trace. Computation used 1,702 gas units:

| Component | Gas units | Share |
|---|---:|---:|
| Read charge, package inputs (105,356 bytes) | 1,580.3 | 92.8% |
| Read charge, object inputs (2,614 bytes) | 39.2 | 2.3% |
| Other charges before execution | 3.4 | 0.2% |
| Move execution (all commands) | 79.4 | 4.7% |
| **Total** | **1,702** | |

The gas model rounds 1,702 units up to 1,710, so the computation cost is 171,000 MIST. The sender's total charge is:

| Component | MIST | Share |
|---|---:|---:|
| Non-refundable storage fee | 241,680 | 58.6% |
| Computation: package read charge | ~158,000 | 38.3% |
| Computation: all other | ~13,000 | 3.1% |
| **Net charged to sender** | **412,680** | |

The transaction's logic, meaning the Move execution for cancelling orders, placing orders, and settling, costs about 7,900 MIST. That is 1.9% of what the sender pays.

## Specification

This SIP makes the following protocol configuration changes in a new protocol version.

### Non-refundable storage fee

Set `storage_rebate_rate` from `9900` to `9999` basis points. The non-refundable share of the storage rebate falls from 1% to 0.01%.

The formula for the sender rebate does not change:

```
sender_rebate = round(storage_rebate × storage_rebate_rate / 10000)
non_refundable_storage_fee = storage_rebate − sender_rebate
```

### Package read charge

Add a protocol configuration parameter `obj_access_cost_read_per_package_kb`, which is the read charge for package inputs in internal gas units per KiB (1,024 bytes). Set it to `154`. One percent of the current rate of 15 internal gas units per byte is 153.6 per KiB, which this SIP rounds to the nearest integer.

When the parameter is set, the input read charge becomes:

```
charge = Σ size(o) × obj_access_cost_read_per_byte
             for each non-package input object o
       + Σ ceil(size(p) × obj_access_cost_read_per_package_kb / 1024)
             for each non-system package input p
```

Each input is charged separately, so the package charge is rounded up per package. The charge for non-package inputs does not change. System packages stay exempt.

The existing per-byte parameter only accepts integers, so it cannot express about 0.15 internal units per byte. That is why this change adds a separate parameter rather than adjusting the existing one.

### Effect on the example transaction

| Component | Current | Proposed |
|---|---:|---:|
| Read charge, packages (gas units) | 1,580.3 | 15.8 |
| Read charge, objects (gas units) | 39.2 | 39.2 |
| Other charges before execution (gas units) | 3.4 | 3.4 |
| Move execution (gas units) | 79.4 | 79.4 |
| **Computation (gas units)** | **1,702** | **137** |
| Computation cost (MIST) | 171,000 | 100,000 |
| Storage cost (MIST) | 24,168,000 | 24,168,000 |
| Storage rebate (MIST) | 23,926,320 | 24,165,583 |
| Non-refundable storage fee (MIST) | 241,680 | 2,417 |
| **Net charged to sender (MIST)** | **412,680** | **102,417** |

The net cost falls by 75%. The computation cost falls to 100,000 MIST and not to 13,700 MIST, because the gas model charges at least 1,000 gas units for every transaction. This SIP does not change that minimum.

The numbers in the "Current" column come from a replay of the transaction. The "Proposed" column combines replayed measurements with the formulas above. The Move execution and object read charges come from a replay with package read charges removed. The package charge and storage rebate are computed from the specified parameters.

## Rationale

### Why 1% and not zero

Setting either charge to zero would create a precedent that the charge can never be raised again. Raising a parameter from a nonzero value is an ordinary protocol change. Adding back a charge that has been removed is a larger change for applications, which may have been designed around its absence. Keeping both charges at 1% of their current values makes their effect small and keeps both parameters available for future tuning.

### Why a separate parameter for packages

Packages and objects have different costs for validators. Objects change and are read from storage. Packages are immutable and cached. A separate parameter lets the protocol price package reads independently of object reads, both now and in the future.

### Alternatives considered

- **Charge packages only on a cache miss.** Whether a package is cached depends on each validator's state, and gas charges must be deterministic across validators. This alternative is not feasible.
- **Remove the charges completely.** This SIP rejects this alternative for the reason given under "Why 1% and not zero."
- **Apply the non-refundable fee only to deletions.** This would remove the per-write charge but keep a fee that has no remaining justification. It would also add a distinction between mutation and deletion to the gas model.

## Backwards Compatibility

Both changes take effect in a new protocol version. Transactions from earlier protocol versions replay with the charges that applied to them.

The changes do not alter any on-wire data structure. `GasCostSummary` keeps the same fields and meanings. Clients that estimate gas through dry runs get the new costs automatically.

Transactions become cheaper, and none become more expensive. Applications that set gas budgets based on past costs keep working.

## Test Cases

- A transaction that calls a non-system package of `N` bytes is charged `ceil(N × 154 / 1024)` internal gas units for that package, and the object read charge is unchanged.
- A transaction that calls only system packages is charged the same as before.
- A transaction that mutates an object without changing its size pays a non-refundable fee of `storage_rebate − round(storage_rebate × 0.9999)`.
- A replay of transactions from earlier protocol versions produces the same effects as before.

## Reference Implementation

- Non-refundable storage fee: https://github.com/MystenLabs/sui/pull/28223
- Package read charge: https://github.com/MystenLabs/sui/pull/28224

## Security Considerations

**Storage fund inflow.** With a lower rate, rewrites and deletions add less to the storage fund's non-refundable balance. Storage deposits for live objects stay in the fund as before, so the fund continues to hold at least the storage fees for all live objects. The fund also keeps receiving reinvested staking rewards.

**Denial of service through repeated writes.** Every transaction that rewrites an object still pays computation gas. It must also deposit the full storage cost of each new version, which it gets back only when the object shrinks or is deleted. The lower non-refundable fee does not let a transaction write data without paying for it.

**Denial of service through large packages.** Packages remain limited to 100 KiB. Validators still pay the cost of loading a package the first time, and every transaction still pays the minimum charge of 1,000 gas units. At 1% of the current rate, each package a transaction names still has a nonzero cost.

## Copyright

[CC0 1.0](../LICENSE.md).
