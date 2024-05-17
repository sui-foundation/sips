| SIP-Number          | <Leave this blank; it will be assigned by a SIP Editor> |
| ---:                | :--- |
| Title               | BLS-12381 Encryption Key Management for Non Private Key Wallet |
| Description         | Specify the key derivation logic for an encryption key server |
| Author              | Joy Wang (@joyqvq, joy@mystenlabs.com)|
| Editor              | <Leave this blank; it will be assigned by a SIP Editor> |
| Type                | Standard |
| Category            | Wallet |
| Created             | 2024-05-09 |
| Comments-URI        | <Leave this blank; it will be assigned by a SIP Editor> |
| Status              | <Leave this blank; it will be assigned by a SIP Editor> |
| Requires            | <Optional; SIP number(s), comma separated> |

## Abstract

While it is proposed in SIP-TODO for a derivation path from a master private key, there are many use cases that a master private key is not available, such as zkLogin wallet and Multisig wallet. Here we propose a key server example on how an encryption key can be derived from a server master seed. 
## Motivation

This SIP is meant to address the gaps for SIP-TODO where the master private key is not available. 

## Specification

In many cases we do not want the user to manage any key material in the wallet. [zkLogin wallet](https://docs.sui.io/concepts/cryptography/zklogin) does not store any persistent private key to be used for derivation. Multisig wallet also does not have a master private key since the signing operation happens differently. 

Here we define a recommended setup for a centralized key server with authentication that can derive and serve a persistent encryption key for each user. 

1. Server holds a master seed. 
2. Server defines an endpoint and an authentication scheme (e.g. [OpenID](https://openid.net/specs/openid-connect-core-1_0.html)). The request contains a JWT token which has an unique user ID.

For example, the endpoint may look like:

```bash
curl -X POST http://0.0.0.0:3000/get_key -H 'Content-Type: application/json' -d '{"token": "$VALID_JWT_TOKEN"}'
'{"key": "26151c5c0cb67ab2f2f37d000374a629ae1b7f35658d1bd5af4954e5c7ff8f81"}'
```

3. The server validates and authenticate the JWT token, then responds with an encryption key by deriving it from master seed with domain separator as `sub || client_id` using [HKDF](https://datatracker.ietf.org/doc/html/rfc5869). 

With a key server, the user does not need to maintain any key material. Simply, the applications that require encryption, can run a centralized server where the master seed is stored securely. Upon authenticated request, it hands out unique encryption keys per user.

## Rationale

This key server is designed for custodial use cases where the application do not wish the user to manage their own encryption key.

## Backwards Compatibility

The encryption key server does not affect any existing wallet features. N/A

## Test Cases

```
| Master Private Key | App ID | User ID | BLS-12381 Encryption Private Key (Hex) | BLS-1239 Encryption Public Key (Hex) | 
| 0000000000000000000000000000000000000000000000000000000000000000 | example_app | 0 | 0748650a7902d2bb550add95a24dc4325bcfdde7d5fef13f14155aa9b7321474 | b673a8dceab62d1563b497a6c2554dd55c5cbd12232ab8e35159c5ec73ac47c5a9dbacfc5b9f5322018f26f37e3d1cb4 | 
| 0000000000000000000000000000000000000000000000000000000000000000 | example_app | 1 | 6c55c62fdfa9035e09caae7b04083661abbd4841d2999823b816c9f59b56dcfd | 92013452cf3a732ed4e71f6d66793fb0a7136dfac5884faa18cabf08017a018bf4a45621c41c7ea524da6198dde021ba | 
| 0000000000000000000000000000000000000000000000000000000000000000 | example_app | 2 | 2850a172853f62eee09f66f864ebfe1ecd6eb48cd093d7279f806105d9061b56 | 810d4afa734d252e995f36fdda2551fd58e496d567b6f67ff686096279052b10345e8158379770e72d4d9144e523e925 | 
| 0000000000000000000000000000000000000000000000000000000000000000 | example_app_2 | 0 | 0ec8bec62b50548c43ec2650b9f7ea392a9e9609531b55f351c8ca40f7e5c6b7 | a2fd14de353deb20568347b6912a6c425e2a468f9fbd3684751f5abd3bf9ae91b57c19c4f1484e6f460396a043a30d96 | 
| 2850a172853f62eee09f66f864ebfe1ecd6eb48cd093d7279f806105d9061b56 | example_app | 0 | 4ba7f11098c7cdb19f871cb15ced14c79ed15b0decb96848f1fc6a7abea9de25 | 863bdf441e2ec513c655113733a9e9ca387a1ac1ba267f46de2c9e82882ec7d5b04981de0def1aef51f5b36f43b19929 | 
```

## Reference Implementation

See implementation in Rust [in option 2](https://github.com/MystenLabs/encrypted-nft-poc/blob/main/cli/README.md#generate-and-derive-encryption-key). 

## Security Considerations

The master seed should be stored securely considering HSM or enclave solutions. The authentication mechanism should also be designed to only serve encryption keys to users that are authenticated. 

## Copyright

[CC0 1.0](../LICENSE.md).
