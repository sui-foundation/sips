|   SIP-Number |  |
|         ---: | :--- |
|        Title | Attestation registry |
|  Description | Open standard for attesters to share signals about packages |
|       Author | Sidestream Labs https://labs.sidestream.tech |
|       Editor |  |
|         Type | Informational |
|      Created | 2025-02-17 |
| Comments-URI |  |
|       Status |  |
|     Requires | N/A |

## Abstract

Open standard for attesters to share signals about packages.

## Motivation

Currently, there is no straightforward way for the users to ensure the safety of a particular package they plan to interact with. This document proposes to create a central registry that will allow:
1. Security professionals to provide various attestations for packages.
2. Regular Sui users can easily discover relevant attestations for a specific package.
3. Package owners to highlight certain attestations related to their package.

## Specification

We propose to develop an official `attestation` package that will act as a central registry for the security-related signals about packages. More specifically, it will define:

- A permissionless `attestation::attest` method for creating attestations of `Attestation<T>` type
    - Each attestation will have a standard set of fields:
        - `id` — UID of the attestation
        - `receiver` — the package address that is being attested
        - `created_by` — the address of the user who created the attestation
        - `pinned_by` — the optional address of the user who pinned the attestation
        - `revoked_by` — the optional address of the user who revoked the attestation
        - `revoke_cap_id` — the ID of the `RevokeCap` (capability to revoke this attestation)
        - `data` — the extra fields of type `T`, defined by the specific "attestation type" package
    - Once created, the attestation is stored inside package `Registry` and is never deleted
    - The user-created attestation is expected to receive `RevokeCap` which can later be used to revoke the attestation (marking it no longer valid) using the `attestation::revoke` method. Note: the package that implements the `T` type can decide to freeze `RevokeCap` (making an attestation type that can not be revoked) or define other arbitrary revocation logic.

- A permissionless `attestation::register_type` method for registering new `AttestationType`s. It will allow anyone to register a package which defines arbitrary `T` type (for example, an `Audit` type which contains fields like `auditUrl` and `auditHash`) and relevant methods to interact with the `attestation` package
    - Creation of a new `AttestationType` will require:
        - `Publisher` object of the package that defined the `T` type.
        - Arrays of matching `fields` and `values` used to create a `Display` object for the new `Attestation<T>` type.
    - Once created, the `Publisher` as well as the newly created `Display` objects will be frozen and can no longer be used to update the package or the `Display` object.
    - Each attestation type package can introduce custom arbitrary logic, for example, restrict users who can issue attestations or define custom revocation logic.
    - The package shall expose at least a standard `attest` function.

- Permissioned `attestation::pin` and `attestation::unpin` methods for highlighting specific attestations, accessible only by the `Publisher`s of the previously attested package.
    - Example usage scenario:
        1. A newly deployed package gets audited, and the auditors issue `Audit` attestation to that package (i.e., specifying the package address as a `receiver` of their attestation).
        2. The `Publisher` of the newly audited package decides to highlight the attestation, calling the `attestation::pin` method.
        3. Block explorers and other frontends that have `attestation` integration could choose to display pinned attestations above all others.
        4. Once pinned, attestation gets revoked by the `RevokeCap` owners or unpinned by the receiver `Publisher` it is no longer highlighted.

## Rationale

The main target of this proposed standard is the end user interacting with packages and modules on the Sui blockchain. Therefore, explorers and wallets should be able to index created attestations and provide contextual information to the users.

We wish to enable the Sui community to define exact attestation types suitable for their needs; therefore, the proposal makes attestations and attestation types fully permissionless and extensible. Although we also plan to define first attestation types and provide intended example usage for common use cases like security audits, those are intentionally not part of this SIP.

## Backwards Compatibility

There are no issues with backward compatibility, as this proposal focuses on establishing a new standard.

## Reference Implementation

Reference implementation is developed by Sidestream Labs in [sidestream-tech/sui-attestation-registry](https://github.com/sidestream-tech/sui-attestation-registry) together with example attestation type packages.

## Security Considerations

The future upgrade of this package might change some of the principles described here.
