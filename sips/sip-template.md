| SIP-Number          | <Leave this blank; it will be assigned by a SIP Editor> |
| ---:                | :--- |
| Title               | BLS-12381 Encryption Key Storage in Wallet |
| Description         | Specify the key derivation path for the  |
| Author              | Joy Wang (@joyqvq, joy@mystenlabs.com)|
| Editor              | <Leave this blank; it will be assigned by a SIP Editor> |
| Type                | Standard |
| Category            | Wallet |
| Created             | 2024-05-09 |
| Comments-URI        | <Leave this blank; it will be assigned by a SIP Editor> |
| Status              | <Leave this blank; it will be assigned by a SIP Editor> |
| Requires            | <Optional; SIP number(s), comma separated> |

## Abstract

An increasing number of applications on Sui demand users to manage an encryption key on the client side. To address this need, we propose this standard and specification for deriving encryption keys from both the master private key and a custodial key management server.

The integration of encryption keys into wallets will expedite the adoption of numerous practical blockchain applications that rely on off-chain encryption and decryption. 

## Motivation

The standard is motivated by few potential applications such as encrypted NFT that requires the user to manage an encryption key in client side wallets. There are already many designs for applications that require encryption and decryption of on-chain data. 

## Specification

We here describes two primary ways that an encryption key can be managed: 

1. We leverage the master private key already stored in the wallet (either in Chrome Extension or mobile device) by defining a new derivation path. 

2. In the case that we do not wish the user to manage any cryptographic material, we propose a key server that manages a master encryption key and serve each user an unique and persistent encryption key upon request. 

### Manage Encryption Key from Non-Custodial Private Key Wallet

We extend the specification for key derivation path to include a new unique derivation path in addition to all the signing keys for different signature schemes. This is domain separated for BLS12381 scheme and for encryption use only. 

| Key scheme  | Use |  Derivation path  |
|---|---|---|
| Ed25519 |  Signature | m/44'/784'/{account}'/{change}'/{address}' |
| ECDSA Secp256k1  | Signature | m/54'/784'/{account}'/{change}/{address} |
| ECDSA Secp256r1  | Signature |  m/74'/784'/{account}'/{change}/{address} |
| BLS12381  | Encryption | m/94'/784'/{account}'/{change}'/{address}' |

We choose to use `94` on the second level to avoid any collisions with key derivation path for other blockchains and use cases. 

To generate multiple BLS-12381 encryption key from the same master private key, it is recommended to increment the `account` level (e.g. `m/94'/784'/0'/0'/0'`, `m/94'/784'/1'/0'/0'`, `m/94'/784'/2'/0'/0'`, etc). Note that the derivation path for the first three rows are already adopted and supported in Sui. The key derivation path is an extension to [SLIP-0010](https://github.com/satoshilabs/slips/blob/master/slip-0010.md). 

The master private key mnemonics encoding is specified by [BIP39](https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki). 

### Manage Encryption Key Custodially by the Application

In many cases we do not want the user to manage any key material in the wallet. One example is [zkLogin wallet](https://docs.sui.io/concepts/cryptography/zklogin) does not store any persistent private key to be used for derivation. Here we define a recommended setup for a centralized key server with authentication that can derive and serve a persistent encryption key for each user. 

1. Server holds a master private key. 
2. Server defines an endpoint and an authentication scheme (e.g. [OpenID](https://openid.net/specs/openid-connect-core-1_0.html)). The request contains a JWT token which has an unique user ID.
```bash
curl -X POST http://0.0.0.0:3000/get_key -H 'Content-Type: application/json' -d '{"token": "$VALID_JWT_TOKEN"}'
'{"key": "26151c5c0cb67ab2f2f37d000374a629ae1b7f35658d1bd5af4954e5c7ff8f81"}'
```

3. The key is a derived from master key with domain separator as `sub || client_id`.

## Rationale

We decide to leverage the existing key management in wallet for the encryption key to minimize the overhead for user to keep track of a proliferation of keys for different purpose. This standard aims to optimize for portability and easy to use. The user can import and export the same master private key or mnemonics, and arrive at the same encryption key across different wallets. 

In the case of where a non-custodial private key is not available, we design the standard to minimize user overhead with key management. For the applications that requires encryption, a centralized server ran by the application can store the master private key securely and hand out encryption keys per user. 

## Backwards Compatibility

Adding an encryption key derivation does not affect existing wallet features such as signing transactions and/or personal messages. This standard does not need to consider backward compatibility.

## Test Cases

### Manage Encryption Key from Non-Custodial Private Key Wallet

```
| Mnemonics | Derivation Path | BLS-12381 Encryption Private Key (Hex) | BLS-1239 Encryption Public Key (Hex) | 
| dove vault canoe aisle tiger layer tape occur arrange control raccoon guilt | m/94'/784'/0'/0'/0 | 26151c5c0cb67ab2f2f37d000374a629ae1b7f35658d1bd5af4954e5c7ff8f81 | 82587479cf572cd6c17b19fcd979ef574da0f372f42498db7e8078319d8b74af73a9e583b54e9113111ada9301e0231a |
| dove vault canoe aisle tiger layer tape occur arrange control raccoon guilt | m/94'/784'/1'/0'/0 | 257f94f04abdc37734e8e637085f9a04eac0a2b81c5a0d39d88d1fa2db12a643 | ad3c8fce5b5f1fb04ecb70c3cb2c1661cee3018c91ad891e744a1bf12a94cfd0a82ce899d459fab06be57ec430e16423 |
| dove vault canoe aisle tiger layer tape occur arrange control raccoon guilt | m/94'/784'/2'/0'/0 | 26b72cb69f5832c2b533a31b6855dc7bbae074e83509d5a4c0bd1873d887b52d | 92cfca130a2a51d4fcfeebe1b6933e9b7fb521abced9310458423fa28dc045817ddeb51cb866eba22c8f6e41ecbb58d5 |
| fix liar panda devote uncle unique boy false adjust music suspect leader | m/94'/784'/0'/0'/0 | 1b8fd59f4d1f9ffe65f1d6fc212df7c80ee966dc5dd3df6866b823eb2296dee6 | a44a0a6594d7feafbeb1d002535d5617a5d1789d68f0fc83d52f55087b91ea608de36f2765429def04661d13ea74f293 |
```

### Manage Encryption Key Custodially by the Application
```
| Master Private Key | App ID | User ID | BLS-12381 Encryption Private Key (Hex) | BLS-1239 Encryption Public Key (Hex) | 
| 0000000000000000000000000000000000000000000000000000000000000000 | example_app | 0 | 0748650a7902d2bb550add95a24dc4325bcfdde7d5fef13f14155aa9b7321474 | b673a8dceab62d1563b497a6c2554dd55c5cbd12232ab8e35159c5ec73ac47c5a9dbacfc5b9f5322018f26f37e3d1cb4 | 
| 0000000000000000000000000000000000000000000000000000000000000000 | example_app | 1 | 6c55c62fdfa9035e09caae7b04083661abbd4841d2999823b816c9f59b56dcfd | 92013452cf3a732ed4e71f6d66793fb0a7136dfac5884faa18cabf08017a018bf4a45621c41c7ea524da6198dde021ba | 
| 0000000000000000000000000000000000000000000000000000000000000000 | example_app | 2 | 2850a172853f62eee09f66f864ebfe1ecd6eb48cd093d7279f806105d9061b56 | 810d4afa734d252e995f36fdda2551fd58e496d567b6f67ff686096279052b10345e8158379770e72d4d9144e523e925 | 
| 0000000000000000000000000000000000000000000000000000000000000000 | example_app_2 | 0 | 0ec8bec62b50548c43ec2650b9f7ea392a9e9609531b55f351c8ca40f7e5c6b7 | a2fd14de353deb20568347b6912a6c425e2a468f9fbd3684751f5abd3bf9ae91b57c19c4f1484e6f460396a043a30d96 | 
| 2850a172853f62eee09f66f864ebfe1ecd6eb48cd093d7279f806105d9061b56 | example_app | 0 | 4ba7f11098c7cdb19f871cb15ced14c79ed15b0decb96848f1fc6a7abea9de25 | 863bdf441e2ec513c655113733a9e9ca387a1ac1ba267f46de2c9e82882ec7d5b04981de0def1aef51f5b36f43b19929 | 
```

## Reference Implementation

See implementation in Rust [here](https://github.com/MystenLabs/encrypted-nft-poc/pull/11). 

## Security Considerations

todo

## Copyright

[CC0 1.0](../LICENSE.md).
