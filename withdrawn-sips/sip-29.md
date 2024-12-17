| SIP-Number          | 29 |
| ---:                | :--- |
| Title               | BLS-12381 Encryption Public Key On-Chain Discoverability |
| Description         | This standardizes an on-chain data structure for an user's BLS encryption public key to be discoverable on-chain. |
| Author              | Joy Wang \<joy@mystenlabs.com, @joyqvq\>|
| Editor              | Alex Tsiliris \<alex.tsiliris@sui.io, @Eis-D-Z\> |
| Type                | Standard |
| Category            | Wallet |
| Created             | 2024-06-24 |
| Comments-URI        | https://sips.sui.io/comments-29 |
| Status              | Withdrawn |
| Requires            | |

## Abstract

Asymmetric encryption enables many applications on Sui. In order to let applications or other users to encrypt anything for a user, the user can create an encryption key locally and post the public key on-chain a prior. This SIP standardizes the on-chain layout for the public key so that applications can scan and encrypt anything for the user. Only the receiver that has the corresponding private key can decrypt the ciphertext and read its plaintext content. 

## Motivation

While it is possible for anyone to post public keys on-chain, it is crucial for the Sui ecosystem to use a standardized object for keys. This enables greater interoperability and usability of the encryption keys. In particular, this standard enables the encrypted NFT marketplace to operate more efficiently, because the public key can be discovered directly by the seller without needing to contact the buyer. The new encryption of the NFT under the new owner can happen more seamlessly. 

## Specification

We define the on-chain public key format as follows:
```move
    public struct UserEncryptionPublicKey has key, store {
        id: UID,
        pk: Element<G1>, // A valid G1 element that represents the public key for the encryption key. 
        description: String // A string that stores additional information about the encryption key. 
    }
```

To create a `UserEncryptionPublicKey` on-chain, an object with the public key and a description is created and transferred to the caller. 

```move
    public fun create_encryption_pk(pk: vector<u8>, description: String, ctx: &mut TxContext) {
        transfer::public_transfer(
            UserEncryptionPublicKey {
                id: object::new(ctx),
                pk: bls12381::g1_from_bytes(&pk),
                description: description
            },
            tx_context::sender(ctx)
        )
    }
```
## Rationale

The public key should be a valid BLS12381 G1 element. This is to accommodate the widely used ElGamal encryption scheme. The private key is a scalar in BLS12381.

The description field can be used to add any identifiers and metadata to the public key. 

## Backwards Compatibility

There are no concerns for backwards compatibility.

## Test Cases

N/A. See public key validation check tests [here](https://github.com/MystenLabs/encryption-public-key).

## Reference Implementation

An implementation of the on-chain public key registration [here](https://github.com/MystenLabs/encryption-public-key).

## Security Considerations

The encryption private key should stay locally and the public key can be discoverable on-chain. There is no secrutity risk to post the public key on-chain. 

## Copyright

[CC0 1.0](../LICENSE.md).
