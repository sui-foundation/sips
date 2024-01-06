| SIP-Number          | <Leave this blank; it will be assigned by a SIP Editor> |
| ---:                | :--- |
| Title               | Use Bech32 encoding for private key in wallets import and exports |
| Description         | Change the encoding for private key from 32-bytes Hex encoding to 33-byte flag and private key in Bech32 encoding for wallets and Sui Keystore import and export interfaces. |
| Author              | Joy Wang (joy@mystenlabs.com) |
| Editor              | <Leave this blank; it will be assigned by a SIP Editor> |
| Type                | Standard |
| Category            | Wallet interface |
| Created             | 2024-01-04 |
| Comments-URI        | <Leave this blank; it will be assigned by a SIP Editor> |
| Status              | <Leave this blank; it will be assigned by a SIP Editor> |
| Requires            | <Optional; SIP number(s), comma separated> |

## Abstract

Currently, both Sui Wallet and Sui Keystore support import and export for private key in 32-byte Hex encoding. This SIP proposes to change the import and export interface only accept 33-bytes `flag || private_key` Bech32 encoded string with human readable part (HRP) as `suiprivkey` for both Sui Wallet and Sui Keystore.

## Motivation

This SIP is proposed to visually distinguish a 32-byte private key representation from a 32-bytes Sui address that is currently also Hex encoded. This prevents human errors to accidentally import Sui address as private key to a wallet, or enter a private key as a Sui address when creating a transaction.

This also always includes the 1-byte flag before 32-byte private key to keep the Sui wallet and the Sui Keystore representation consistent. No appending flag byte is required when importing and exporting from Sui Wallet to Sui Keystore or vice versa.

## Specification

To import a private key to Sui Keystore or Sui Wallet, a Bech32 encoded 33-byte `flag || private_key` must be supplied. 

To export a private key from Sui Keystore or Sui Wallet, a Bech32 encoded 33-byte `flag || private_key` is output.

See [BIP-173](https://github.com/bitcoin/bips/blob/master/bip-0173.mediawiki) for Bech32 encoding specifications. The human readable part (HRP) for Sui private key is defined as `suiprivkey`.

### What Changed

Sui Keytool CLI
1. `sui keytool convert`: Add a new keytool command to convert a legacy format to the new Bech32 format. 
2. `sui keytool export`: Add a new keytool command to export a Bech32 format private key from Sui Keystore.  
3. `sui keytool import`: Modify the behavior of the existing import private key command to disallow Hex encoded 32-byte private key and only allow the new Bech32 format. 

Sui Wallet and SDK

1. 

## Rationale

The proposed encoding change from Hex to Bech32 for private key is to clearly distinguish a Sui address (32-byte Hex) from a Sui private key. 

Why Bech32? It is the most modern encoding standardized by Bitcoin. It supports checksum and eliminates error-prone characters. In addition, It contains a human readable part (HRP) indicating it is a private key very noticeably (i.e. "suiprivkey"). 

See [BIP-173](https://github.com/bitcoin/bips/blob/master/bip-0173.mediawiki) for more, note that Bitcoin uses Bech32 for address encoding, whereas this SIP proposes Bech32 encoding for Sui private key standard. 

With the new encoding, a private key will not be validated by Sui Wallet as a Sui address, given its length and its different encoding in wallet. It should not be confused as a Sui address (32-byte Hex encoded) or transaction digest (32-byte Base58 encoding).

## Backwards Compatibility

This change is **NOT** backward compatible. The legacy Hex encoded private keys can no longer be imported and exported for Sui Wallet and Sui CLI keystore after this change.

To use the latest Sui Wallet and CLI keystore, a user must first make sure the Hex encoding 32-byte is indeed a private key (instead of a Sui address or anything else), then use the CLI tool to convert to Bech32 encoding. 

Example

```bash
sui keytool convert 0x1b87a727f58830d9ba2bfe6ecdc8fb49aa96fa2a2bbe175e128bfee13f6895ff
```

## Test Cases
| Bech32 format (33-byte with flag) | Hex format (32-byte, assumes Ed25519 flag) | Base64 format (33-byte with flag) | Sui address | 
|---|---|---|---|
| suiprivkey1qzwant3kaegmjy4qxex93s0jzvemekkjmyv3r2sjwgnv2y479pgsywhveae | 0x9dd9ae36ee51b912a0364c58c1f21333bcdad2d91911aa127226c512be285102 | AJ3ZrjbuUbkSoDZMWMHyEzO82tLZGRGqEnImxRK+KFEC | 0x90f3e6d73b5730f16974f4df1d3441394ebae62186baf83608599f226455afa7 |
| suiprivkey1qrh2sjl88rze74hwjndw3l26dqyz63tea5u9frtwcsqhmfk9vxdlx8cpv0g | 0xeea84be738c59f56ee94dae8fd5a68082d4579ed38548d6ec4017da6c5619bf3 | AO6oS+c4xZ9W7pTa6P1aaAgtRXntOFSNbsQBfabFYZvz | 0xfd233cd9a5dd7e577f16fa523427c75fbc382af1583c39fdf1c6747d2ed807a3 |
| suiprivkey1qzg73qyvfz0wpnyectkl08nrhe4pgnu0vqx8gydu96qx7uj4wyr8gcrjlh3 | 0x91e8808c489ee0cc99c2edf79e63be6a144f8f600c7411bc2e806f7255710674 | AJHogIxInuDMmcLt955jvmoUT49gDHQRvC6Ab3JVcQZ0 | 0x81aaefa4a883e72e8b6ccd3bec307e25fe3d79b14e43b778695c55dcec42f4f0 |

## Reference Implementation

[PR](https://github.com/MystenLabs/sui/pull/15415)

## Security Considerations

This SIP reduces risks for a user mixing usage of a private key and a Sui address, hence increases the security of Sui Wallet and Sui Keystore.

## Copyright

[CC0 1.0](../LICENSE.md).