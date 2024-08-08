| SIP-Number          | 28 |
| ---:                | :--- |
| Title               | BLS-12381 Encryption Key Storage in Wallet |
| Description         | Specify the key derivation path for the BLS-12381 Encryption Key for wallet master private key. |
| Author              | Joy Wang <joy@mystenlabs.com, @joyqvq> |
| Editor              | Alex Tsiliris <alex.tsiliris@sui.io, @Eis-D-Z> |
| Type                | Standard |
| Category            | Wallet |
| Created             | 2024-05-09 |
| Comments-URI        | https://sips.sui.io/comments-28 |
| Status              | Draft |
| Requires            | - |

## Abstract

Many applications on Sui demand users to manage encryption keys on the client side. To address this need, we propose this standard and specification for deriving BLS12381 encryption keys from the master private key in the wallet. 

The integration of encryption keys into wallets will expedite the adoption of numerous practical blockchain applications that rely on off-chain encryption and decryption. 

## Motivation

The standard is motivated by few potential applications such as encrypted NFT that requires the user to manage a BLS 12381 encryption key in client side wallet. There are already many designs for applications that require encryption and decryption of on-chain data. 

The existing key derivation standard such as [BIP-32](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki) is no longer applicable since the derived keys are greater than the curve order and no longer valid. 

## Specification

We leverage the master private key already stored in the wallet (either in Chrome Extension or mobile device) and define a new derivation pfunction and a new derivation path to derive BLS12381 encryption key. 

1. From Seed to Master SK
```
master_sk = hkdf_mod_r(seed)
```
mnemonics -> seed: BIP39
seed -> bls master: BLS(https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-bls-signature-05#name-keygen)
not: seed -> master is bip 32

2. From parent SK to child SK
```
function parent_sk_to_child_sk(parent_sk, index): 

ikm -> bls_sk -> child_ikm

ikm -> bls_sk 
ikm, domain -> child_ikm
```
index: 1 < index <= 255

Helper functions

```
function IKM_to_sk(IKM, salt):
    PRK = HKDF-Extract(salt, IKM)
    OKM = HKDF-Expand(PRK, "" , L)
    bytes_split(OKM, K)
```

```
function hkdf_mod_r(IKM): 
    salt = "BLS-ENC-KEYGEN-SALT-"
    SK = 0
    while SK == 0:
        PRK = HKDF-Extract(salt, IKM || I2OSP(0, 1))
        OKM = HKDF-Expand(PRK, key_info || I2OSP(L, 2), L)
        SK = OS2IP(OKM) mod r
        salt = H(salt)
    return SK
```

### Derivation Path

Now we define derivation path that we can derive from a master SK to a child SK. At each level of the derivation path, we use `parent_sk_to_child_sk(parent_sk, index)` to compute each intermediate parent SK. [BIP-44](https://github.com/bitcoin/bips/blob/master/bip-0044.mediawiki) is used for the HD derivation path. For example, for path `m/94'/784'/0'/0'0`, we derive the child sk from the master sk as `parent_sk_to_child_sk(parent_sk_to_child_sk(parent_sk_to_child_sk(parent_sk_to_child_sk(parent_sk_to_child_sk(master_sk, 94), 784), 0), 0), 0)`.

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

## Rationale

We decide to leverage the existing key management in wallet for the encryption key to minimize the overhead for user to keep track of a proliferation of keys for different purpose. This standard aims to optimize for portability and easy to use. The user can import and export the same master private key or mnemonics seamlessly, and derives to the same encryption key across different wallets. 

For wallets where a single master private key is not available, such as multisig wallet or zkLogin wallet, it is out of scope for this SIP. A separate SIP for a key server solution will be posted. 

## Backwards Compatibility

Adding an encryption key derivation does not affect existing wallet features such as signing transactions and/or personal messages. This standard does not need to consider backward compatibility.

## Test Cases

```
| Mnemonics | Derivation Path | BLS-12381 Encryption Private Key (Hex) | BLS-1239 Encryption Public Key (Hex) | 
| dove vault canoe aisle tiger layer tape occur arrange control raccoon guilt | m/94'/784'/0'/0'/0 | 26151c5c0cb67ab2f2f37d000374a629ae1b7f35658d1bd5af4954e5c7ff8f81 | 82587479cf572cd6c17b19fcd979ef574da0f372f42498db7e8078319d8b74af73a9e583b54e9113111ada9301e0231a |
| dove vault canoe aisle tiger layer tape occur arrange control raccoon guilt | m/94'/784'/1'/0'/0 | 257f94f04abdc37734e8e637085f9a04eac0a2b81c5a0d39d88d1fa2db12a643 | ad3c8fce5b5f1fb04ecb70c3cb2c1661cee3018c91ad891e744a1bf12a94cfd0a82ce899d459fab06be57ec430e16423 |
| dove vault canoe aisle tiger layer tape occur arrange control raccoon guilt | m/94'/784'/2'/0'/0 | 26b72cb69f5832c2b533a31b6855dc7bbae074e83509d5a4c0bd1873d887b52d | 92cfca130a2a51d4fcfeebe1b6933e9b7fb521abced9310458423fa28dc045817ddeb51cb866eba22c8f6e41ecbb58d5 |
| fix liar panda devote uncle unique boy false adjust music suspect leader | m/94'/784'/0'/0'/0 | 1b8fd59f4d1f9ffe65f1d6fc212df7c80ee966dc5dd3df6866b823eb2296dee6 | a44a0a6594d7feafbeb1d002535d5617a5d1789d68f0fc83d52f55087b91ea608de36f2765429def04661d13ea74f293 |
```

## Reference Implementation

See implementation in Rust [here](https://github.com/MystenLabs/encrypted-nft-poc/blob/main/cli/README.md#generate-and-derive-encryption-key). 

## Security Considerations

The master private key storage is unchanged in the wallet. It is always stored securely in the wallet storage (chrome extension or mobile device). The derivation of the encryption key happens in the wallet as well. Dapp communicates to the wallet for materials to encrypt and decrypt through an interface, so that the encryption key itself does not leave the wallet context. The security level is as secure as the signing private keys that the wallet. 

## Copyright

[CC0 1.0](../LICENSE.md).
