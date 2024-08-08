| SIP-Number          | 27 |
| ---:                | :--- |
| Title               | BLS-12381 Encryption Key Management for Non Private Key Wallet |
| Description         | Specify the key derivation logic for an encryption key server |
| Author              | Joy Wang (@joyqvq, joy@mystenlabs.com)|
| Editor              | Alex Tsiliris <alex.tsiliris@sui.io, @Eis-D-Z>
| Type                | Standard |
| Category            | Wallet |
| Created             | 2024-05-09 |
| Comments-URI        | https://sips.sui.io/comments-27 |
| Status              | Draft |
| Requires            | |

## Abstract

While it is proposed in SIP-TODO for a derivation path from a master private key, there are many use cases that a master private key is not available for a wallet, such as [zkLogin wallet](https://docs.sui.io/concepts/cryptography/zklogin) and Multisig wallet. Here we propose a key server example on how an encryption key can be derived from a server master encryption seed based on a unique user identifier. This is an alternative custodial solution to encryption key management, in addition to the non-custodial derivation path. 

## Motivation

This SIP is proposed as a custodial encryption key derivation solution to address the gaps for SIP-TODO where the master private key is not available. 

## Specification

Here we define a recommended setup for a centralized key server with authentication that can derive and serve a persistent encryption key for each user. 

1. Server holds a master seed. This is recommended to store in an Trusted Execution Environment such as enclave or HSM. 
2. Server defines an endpoint and an authentication scheme. The request contains an unique user ID and an application ID.
3. The server validates and authenticates the request, then derives a 48-byte bytearray from the master seed with domain separator using [HKDF](https://datatracker.ietf.org/doc/html/rfc5869): `HKDF(ikm=master key, salt = app_id, info = user_id)`. Then it reduces a big-endian integer of arbitrary size modulo the scalar field size according to [this spec](https://eips.ethereum.org/EIPS/eip-2333#hkdf_mod_r) return the scalar as the encryption private key. 

The algorithm can be applied to BLS-12381 as well as Ristretto group. The field order for for BLS-12381 is defined [here](https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-bls-signature-05) as `52435875175126190479447740508185965837690552500527637822603658699938581184513`.

The `user_id` must be unique to ensure that each user receives a distinct encryption key. 

The `app_id` must be unique per application if the server hands out encryption key for more than one application. 

## Rationale

With a key server, the user does not need to maintain any key material. Simply, the applications that require encryption feature, can run a centralized server where the master seed is stored securely. Upon authenticated request, it hands out unique encryption keys per user per application.

## Backwards Compatibility

The encryption key server does not affect any existing wallet features and therefore does not introduce backward compatibility. 

## Test Cases

Test cases here are generated in BLS-12381 with the following CLI tool with the implementation [here](https://github.com/MystenLabs/encrypted-nft-poc/cli).

```bash
cargo build --release
target/release/enft-cli derive-encryption-key -m $MASTER_PRIV_KEY -a $APP_ID -u $USER_ID
```

```
| Master Private Key | App ID | User ID | BLS-12381 Encryption Private Key (Hex) | BLS-1239 Encryption Public Key (Hex) | 
| 0000000000000000000000000000000000000000000000000000000000000000 | example_app | 0 | 1951b5a79806a7c503c9456b7e20e46a37e2bf3c59b42d351b268b7a3a4bce1b | 8846743e175869c7fe8906aa24b22e24caaf8059125cbc944f9b38e77756665fa5e13b3e97203de7ad32d1c12e7ca5df | 
| 0000000000000000000000000000000000000000000000000000000000000000 | example_app | 1 | 04367fc70d7b9c5923bc36aea406082254d3894ec4b0c21bfe830199ea2b9398 | 859d28809cf40c43895e371dec0d74f9764133763774adbaffa75e5032d92d68713a58cdd0eb00bc8bc6199db952ef04 | 
| 0000000000000000000000000000000000000000000000000000000000000000 | example_app | 2 | 13c232cc2d199aa6f5c17a5713111668444a1161dd4e9ad5e7fb026bc30c3196 | a390660a3905b7b24dba110fe55c68644c15726fa0cab091db531c2ca90675d29453e343db409911fac7a1c67c0b34ee | 
| 0000000000000000000000000000000000000000000000000000000000000000 | example_app_2 | 0 | 6fdca5cab0796efe2f9947b0e5a1ac41424285fd854d6dbf1cd6aeffe6452142 | aed667a1a709b96d47d09704e43cfadb031bc7ea98b6c17ab2e017e9ed1c6932f0c91c29b054762f9e8bea9970a08afd | 
| 2850a172853f62eee09f66f864ebfe1ecd6eb48cd093d7279f806105d9061b56 | example_app | 0 | 28e73ca98a21c0fe530117c9734b0fea4ea16dcc01efec636a092e2a5702b5d3 | 8ccc507f36fa3154d12b7ab0ed5cb8c2996a3b098cc9ca451ee2a7f29e9c5bd44ba9bb3db22116331c00b9e21c5cd5f8 | 
```

## Reference Implementation

See implementation in Rust [in option 2](https://github.com/MystenLabs/encrypted-nft-poc/blob/main/cli/README.md#generate-and-derive-encryption-key). 

## Security Considerations

The master seed should be stored securely considering HSM or enclave solutions. Otherwise, the compromise of the master seed implies all encryption key derived are compromised. In addition, the response containing users' encryption key should be sent over a TLS channel that is established between the user front-end and the HSM.

The authentication mechanism should be designed to only serve encryption keys to users that are authenticated. Otherwise, anyone can request an encryption key on behalf of other users. An authentication scheme can be considered is [OpenID](https://openid.net/specs/openid-connect-core-1_0.html) where `sub` is used as user ID and `aud` is used as the app ID. 

## Copyright

[CC0 1.0](../LICENSE.md).