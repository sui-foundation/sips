| SIP-Number          | 44 |
| ---:                | :--- |
| Title               | Multi-Address Object Usage in Transactions |
| Description         | Enable transactions to use objects owned by multiple addresses with appropriate signatures |
| Author              | Cyril Morlet \<fetch@sceat.xyz\> |
| Editor              | Will Riches \<will@sui.io, @wriches\>  |
| Type                | Standard |
| Category            | Core |
| Created             | 2024-11-22 |
| Comments-URI        | https://sips.sui.io/comments-44 |
| Status              | Draft |
| Requires            | |

## Abstract

This SIP proposes extending Sui's transaction model to allow using objects owned by multiple addresses within a single transaction, provided all relevant address owners sign the transaction. This enhancement would enable secure multi-party atomic operations while maintaining Sui's ownership and security model.

## Motivation

Currently, Sui transactions can only use objects owned by the transaction sender, with a limited exception for a single gas sponsor. This restriction prevents several valuable use cases:

1. Server-assisted operations where a server needs to provide admin/authority objects while users provide their own objects
2. Direct peer-to-peer exchanges where two users want to atomically swap objects
3. Multi-signature operations where multiple parties need to contribute specific objects to a transaction
4. Multiple parties contributing to transaction gas costs, allowing fair distribution of fees in collaborative operations

While single-party gas sponsorship exists, there's no mechanism to securely include objects from multiple owners or allow multiple parties to contribute to gas costs in a single atomic operation. This leads to complex multi-step transactions that are vulnerable to race conditions and require trust between parties.

## Specification

I propose extending the transaction system to:

1. Allow transactions to reference objects owned by multiple addresses
2. Require signatures from all addresses that own objects used in the transaction
3. Maintain the existing sender model while adding additional object-owner signatures
4. (optional) Enable multiple addresses to contribute gas objects to the same transaction

The execution flow would be:

1. Transaction creation includes list of all participating addresses
2. Each required signer adds their signature
3. Validation ensures all object owners have signed
4. Normal transaction execution proceeds with expanded object access

## Rationale

This design would:

1. Maintains Sui's strong ownership model by requiring signatures from all object owners
2. Enables atomic multi-party operations while preserving the existing security model
3. Provides flexibility for gas cost sharing without compromising the transaction model

## Backwards Compatibility

This change is backwards compatible:
- Existing transactions remain valid with their current structure
- New transaction format is a superset of the current format
- No changes required for existing smart contracts

## Security Considerations

1. Signature Verification
   - All signatures must be valid
   - Order of signatures must not affect validation
   - Clear failure modes for missing signatures

2. Object Access Control
   - Strict validation of object ownership
   - Prevention of unauthorized object access
   - Clear transaction failure if any object becomes unavailable

3. Gas Safety
   - Gas contribution amounts must be clearly specified
   - Gas object ownership must be verified just like regular objects
