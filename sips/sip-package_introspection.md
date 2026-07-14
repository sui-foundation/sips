|   SIP-Number | |
|         ---: | :--- |
|        Title | Permissionless Package Introspection |
|  Description | Adds native functions to query package execution identity, upgrade state, lineage, version, and resolved dependencies without holding the UpgradeCap. |
|       Author | Greshamscode, @92GC |
|       Editor | <Leave this blank; it will be assigned by a SIP Editor> |
|         Type | Standard |
|     Category | Framework |
|      Created | 2025-06-25 |
| Comments-URI | |
|       Status | |
|     Requires | |

## Abstract

This proposal adds native functions to `sui::package` for permissionlessly querying the currently executing package, effective upgrade policy, immutability, version, upgrade lineage, and resolved dependencies.

These queries allow governance and integration contracts to verify package provenance and upgrade state without possessing the package's `UpgradeCap`.

## Motivation

The existing package APIs expose version and upgrade policy through an `UpgradeCap`. This is insufficient for contracts integrating third-party packages because the cap is normally held by the package publisher, may be wrapped inside another object, and is destroyed when the package becomes immutable.

Contracts also cannot currently answer:

- Which physical package version is executing this function?
- Does this package descend from the approved original package?
- What is the package's effective upgrade policy?
- Is the package immutable?
- Which concrete version of a dependency was selected by this package?

A version number alone is not proof of identity. An unrelated package can have the same version number, and a package can be linked against upgraded dependency versions that differ from those reviewed by governance.

## Specification

```move
module sui::package {
    /// Physical package ID containing the function that directly invoked this native.
    public native fun current_package_id(): address;

    /// Effective upgrade policy for the package's upgrade lineage.
    /// 0=COMPATIBLE, 128=ADDITIVE, 192=DEP_ONLY, 255=IMMUTABLE.
    public native fun policy_for(package_id: address): u8;

    /// True if the package's upgrade lineage can no longer be upgraded.
    public native fun is_immutable(package_id: address): bool;

    /// Protocol package version stored for this physical package.
    public native fun version_for(package_id: address): u64;

    /// Stable original package ID for this package's upgrade lineage.
    public native fun original_package_id(package_id: address): address;

    /// Concrete dependency package selected for an original dependency ID.
    /// Returns None if the package does not depend on that lineage.
    public native fun dependency_package(
        package_id: address,
        dependency_original_id: address,
    ): Option<address>;
}
```

All functions taking a `package_id` abort if the address does not identify a Move package, except that `dependency_package` returns `None` for a valid package with no matching dependency.

`current_package_id()` returns the physical package containing its direct Move caller. Calling it through a wrapper package therefore identifies the wrapper, not an earlier package in the call stack.

`dependency_package` resolves against the package's recorded linkage table. Its input key is the dependency's stable original package ID, and its result is the concrete physical package ID selected by the queried package.

## Use Cases

- Enforce immutable or additive-only packages in DAO action registries.
- Verify that an action package descends from an approved original package.
- Pin governance proposals to a specific package version or physical package ID.
- Verify which concrete dependency versions a third-party package uses.
- Reject substituted packages that share a version number but belong to another lineage.
- Apply minimum-version requirements without possessing another project's `UpgradeCap`.

## Rationale

- **Why `sui::package`?** It already defines Sui's package upgrade types and policies.
- **Why native functions?** Move cannot dynamically load package objects or inspect the caller's physical package ID using ordinary object inputs.
- **Why lineage?** Package IDs change across user-package upgrades; the original package ID provides a stable family identity.
- **Why dependency resolution?** Auditing a package requires knowing the concrete dependency versions selected by its linkage table.
- **Why separate `policy_for` and `is_immutable`?** Immutability is a common security decision and should not require callers to interpret policy constants.

Package version, lineage, and dependency linkage are stored in package metadata. Upgrade policy and immutability may require protocol-maintained lineage metadata because the `UpgradeCap` is an independently owned object that can be transferred, wrapped, restricted, or destroyed.

## Non-Goals

This SIP does not expose an exact package-content digest. Bytecode and dependency digest attestation can be proposed separately.

It also does not grant upgrade authority, inspect arbitrary Move-object contents, or determine whether two package versions are semantically equivalent.

## Backwards Compatibility

Purely additive. Existing `UpgradeCap`, `Publisher`, and package-upgrade functions remain unchanged.

## Test Cases

- Return the physical package ID of a direct caller.
- Return version and original package ID for initial and upgraded packages.
- Return the effective compatible, additive, and dependency-only policies.
- Report immutability after the `UpgradeCap` is destroyed.
- Resolve a dependency's original ID to the concrete linked package ID.
- Return `None` for a valid but absent dependency.
- Reject addresses that do not identify Move packages.
- Define behavior while an upgrade is authorized but not yet committed in the same transaction.

## Reference Implementation

To be developed.

## Security Considerations

- All functions are read-only and grant no upgrade capability.
- Results must be consensus-deterministic and derived from authenticated package metadata.
- Policy and immutability metadata must remain synchronized with restriction and destruction of an `UpgradeCap`.
- Callers must not treat a version number alone as proof of package identity.
- Dependency queries identify linked packages but do not attest that their behavior is safe.

## Copyright

Greshamscode 2025
