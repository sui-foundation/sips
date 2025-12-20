|   SIP-Number | 57 |
|         ---: | :--- |
|        Title | `UpgradedPackageEvent` |
|  Description | Introduces adding `UpgradedPackageEvent` to the Sui Framework |
|       Author | Kevin \<github@aftermath.finance, @admin-aftermath\>, Aftermath Finance \<[aftermath.finance](https://aftermath.finance/)\> |
|       Editor | TBD |
|         Type | Standard |
|     Category | Framework |
|      Created | 2024-05-10 |
| Comments-URI | TBD |
|       Status | Draft |
|     Requires | N/A |

## Abstract

This SIP proposes adding a new event--`UpgradePackageEvent`--to the Sui framework that is emitted whenever a package is upgraded. This event would provide better observability into package upgrades, allowing developers to better monitor and prepare for the versioning of packages they depend on.

> As Sui will continue to evolve over time, a snapshot of the Sui repo will be used when referencing Sui Framework code. This SIP uses the latest stable version of mainnet: `mainnet-v1.47.1`.<sup>[1](https://github.com/MystenLabs/sui/tree/mainnet-v1.47.1)</sup>

## Background

**Upgrading.** On Sui, smart contracts are encapsulated into Sui Move packages and published as singular, immutable objects. The publisher of a package receives an `UpgradeCap` granting them the authority to control the package's upgrade cycle. Packages themselves can be marked as:
 1. mutable,
 1. immutable w/ mutable dependencies, or
 1. immutable.

**Versioning.** Every time a package is upgraded, a new immutable object is created; the previous package is ***not*** modified and remains callable. For this reason, Sui Move best practices recommend versioning packages to allow disabling interaction with outdated package versions. This creates two distinct events during a package's upgrade cycle:
 1. **Upgrade Event.** The moment when the package is upgraded (e.g., from a call to `sui client upgrade`),
 1. **Versioning Event.** The moment when the package is versioned (e.g., from a call to the package's `upgrade_version` function), disabling interaction with previous versions.

 Any amount of time can exist in between events (1) and (2), with (2) being the event that can brick your own package. There is no native way of handling versioning, leading to it being an opt-in "feature" for each package. As such, observability on (2) is dependent on each package individually.

## Motivation

**Limitations.** As a developer with many third-party dependencies, you need to be aware of and prepared for a versioning event ahead of time. If a depended-on package allows for it (e.g., by filtering for `PackageVersionedEvent`s), you can observe the moment the package is versioned. This is not enough, however, as this will likely alert that a piece of your Move package is no longer functioning as it is now attempting to interact with an outdated dependency version; you need to be aware of the moment a package is upgraded in order to begin preparing for the versioning event.

&nbsp;&nbsp;&nbsp;&nbsp; Currently, when a package is upgraded on Sui, there is no native event that is emitted to notify that the upgrade occurred. While the upgrade is recorded through the mutation of the `UpgradeCap` object, it is not always possible to build observability behind the `UpgradeCap` itself.
> For example, afSUI's `UpgradeCap` has been wrapped into a `QuorumUpgradeCap`<sup>[2](https://github.com/MystenLabs/apps/blob/main/upgrade_policy/quorum_upgrade/sources/quorum_upgrade_policy.move#L67-L80)</sup> object, which gives the appearance that it has been deleted.<sup>[3](https://suivision.xyz/object/0xaa2ed7faaea34db19acd21f5d6ba009f71e5ccc7e934a37d2ec72088af547784)</sup>

**Observability.** Adding a native event that is emitted upon package upgrades would allow developers to build better observability behind the packages they depend on, leading to the creation of more robust products on Sui and alleviating the need for strict communication between projects before package upgrades.

## Prerequisites

There are no prerequisites for this SIP.

## Specification

The `UpgradedPackageEvent` will be added to the `sui::package` module of the Sui framework.

```Rust
public struct UpgradedPackageEvent has copy, drop {
    /// The address of the original package (the first version that was published).
    original: address,
    /// The address of the previous package version that is being upgraded.
    previous: address,
    /// The address of the newly created package resulting from the upgrade.
    new: address,
    /// The number of upgrades that have been applied successively to the original package.
    version: u64,
}
```

This event will be emitted from within the `commit_upgrade`<sup>[4](https://github.com/MystenLabs/sui/blob/mainnet-v1.47.1/crates/sui-framework/packages/sui-framework/sources/package.move#L296-L306)</sup> function in the `sui::package` module.

A `native` function--`to_original_package_address`--will be added to the `sui::address` module to allow querying the original `published-at` address for a provided package address.

```Rust
/// Returns the original `published-at` address of the provided package.
public native fun to_original_package_address(cap: &UpgradeCap): ID;
```

## Rationale

By adding the `UpgradedPackageEvent`, developers will be able to build generalized observability behind the packages they depend on.

## Backwards Compatibility

This SIP presents no issues with backwards compatibility.

## Reference Implementation

This SIP requires two general changes, the changes to the Sui Framework's `package` + `address` modules and the required native function implementation. The relevant changes are detailed below.

### ia. `sui::package` Module

```Rust
public struct UpgradedPackageEvent has copy, drop {
    /// The address of the original package (the first version that was published).
    original: address,
    /// The address of the previous package version that is being upgraded.
    previous: address,
    /// The address of the newly created package resulting from the upgrade.
    new: address,
    /// The number of upgrades that have been applied successively to the original package.
    version: u64,
}

...

/// Consume an `UpgradeReceipt` to update its `UpgradeCap`, finalizing
/// the upgrade.
public fun commit_upgrade(cap: &mut UpgradeCap, receipt: UpgradeReceipt) {
    use sui::event::emit;

    let UpgradeReceipt { cap: cap_id, package: new_package } = receipt;

    assert!(object::id(cap) == cap_id, EWrongUpgradeCap);
    assert!(cap.package.to_address() == @0x0, ENotAuthorized);

    let previous_package = cap.package.to_address();
    let new_version = cap.version + 1;
    emit(UpgradedPackageEvent {
        original: previous_package.to_original_package_address(),
        previous: previous_package,
        new: new_package,
        version: new_version,
    });

    cap.package = new_package;
    cap.version = new_version;
}
```

### ib. `sui::address` Module

```Rust
/// Returns the original `published-at` address of the provided package.
public native fun to_original_package_address(package: address): address;

```

### ii. `to_original_package_address` Function Implementation

The implementation of `to_original_package_address` is left out of the first version of this SIP.

## Security Considerations

This SIP is non-invasive and presents no security considerations.

## References

1. [[Sui Repo] mainnet-v1.47.1](https://github.com/MystenLabs/sui/tree/mainnet-v1.47.1)
1. [[MystenLabs Apps] `QuorumUpgradeCap`](https://github.com/MystenLabs/apps/blob/main/upgrade_policy/quorum_upgrade/sources/quorum_upgrade_policy.move#L67-L80)
1. [[Explorer] afSUI `UpgradeCap`](https://suivision.xyz/object/0xaa2ed7faaea34db19acd21f5d6ba009f71e5ccc7e934a37d2ec72088af547784)
1. [[Sui Repo] `sui::package::commit_upgrade`](https://github.com/MystenLabs/sui/blob/mainnet-v1.47.1/crates/sui-framework/packages/sui-framework/sources/package.move#L296-L306)

## Copyright

[CC0 1.0](../LICENSE.md).
