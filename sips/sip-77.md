|   SIP-Number | 77 |
|         ---: | :--- |
|        Title | Nested MultiSig |
|  Description | Allows a MultiSig to be a weighted member of another MultiSig, enabling native, on-chain AND / OR signing policies |
|       Author | Kevin \<github@aftermath.finance, @admin-aftermath\>, Aftermath Finance \<[aftermath.finance](https://aftermath.finance/)\> |
|       Editor | TBD |
|         Type | Standard |
|     Category | Core |
|      Created | 2026-10-28 |
| Comments-URI | TBD |
|       Status | Draft |
|     Requires | N/A |

## Abstract

This SIP proposes allowing a MultiSig to be a member of another MultiSig. Today a MultiSig member must be a single key (Ed25519, Secp256k1, Secp256r1, zkLogin, Passkey, or ML-DSA-65). This SIP adds a new kind of member: the address of an inner MultiSig. The transaction carries the inner MultiSig's signatures, bitmap, and public key, and validators verify them with the same code that verifies the outer MultiSig.

With nested MultiSigs, validators enforce signing policies that a single weighted threshold cannot express, such as `(A AND B) OR 2-of-3(X, Y, Z)`, without off-chain MPC or a custom Move governance module. The change is small: it reuses the address check Sui runs on top-level MultiSigs today.

> As Sui will continue to evolve over time, a snapshot of the Sui repo will be used when referencing Sui code. This SIP uses the latest stable version of mainnet: `mainnet-v1.82.3`.<sup>[1](https://github.com/MystenLabs/sui/tree/bf4073918ed33cfa0b09c500658fa116a774bcfd)</sup>

## Background

**MultiSig.** Sui supports weighted k-of-n MultiSig accounts at the protocol level. A `MultiSigPublicKey` defines each MultiSig: a list of up to 10 `(PublicKey, weight)` pairs and a `threshold`.<sup>[2](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-types/src/multisig.rs#L546-L551)</sup> Validators authorize a transaction when the weights of the signing members sum to at least the threshold.

```Rust
pub type WeightUnit = u8;
pub type ThresholdUnit = u16;
pub type BitmapUnit = u16;
pub const MAX_SIGNER_IN_MULTISIG: usize = 10;

pub struct MultiSigPublicKey {
    pk_map: Vec<(PublicKey, WeightUnit)>,
    threshold: ThresholdUnit,
}

pub struct MultiSig {
    /// The plain signature encoded with signature scheme.
    sigs: Vec<CompressedSignature>,
    /// A bitmap that indicates the position of which public key the signature should be authenticated with.
    bitmap: BitmapUnit,
    /// The public key encoded with each public key with its signature scheme used along with the corresponding weight.
    multisig_pk: MultiSigPublicKey,
    ...
}
```

**Addresses.** A MultiSig address is the Blake2b hash of the MultiSig's configuration: `flag_MultiSig || threshold || flag_1 || pk_1 || weight_1 || ... || flag_n || pk_n || weight_n`.<sup>[3](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-types/src/base_types.rs#L988-L1008)</sup> No private key exists for that address, so a MultiSig cannot produce a signature on its own.

**Members.** The set of valid members is a closed enum.<sup>[4](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-types/src/crypto.rs#L281-L292)</sup> Its signature enum, `CompressedSignature`, mirrors it one-to-one.<sup>[5](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-types/src/crypto.rs#L1878-L1887)</sup>

```Rust
pub enum PublicKey {
    Ed25519(Ed25519PublicKeyAsBytes),
    Secp256k1(Secp256k1PublicKeyAsBytes),
    Secp256r1(Secp256r1PublicKeyAsBytes),
    ZkLogin(ZkLoginPublicIdentifier),
    Passkey(Secp256r1PublicKeyAsBytes),
    MLDSA65(Box<MLDSA65PublicKeyAsBytes>),
}
```

&nbsp;&nbsp;&nbsp;&nbsp; This enum has been extended three times, each behind its own protocol feature flag: zkLogin (`accept_zklogin_in_multisig`), Passkey (`accept_passkey_in_multisig`, SIP-9<sup>[6](https://github.com/sui-foundation/sips/blob/main/sips/sip-9.md)</sup>), and, most recently, ML-DSA-65 (`mldsa65_auth`).<sup>[7](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-protocol-config/src/lib.rs#L664-L670)</sup> None of its variants represents a MultiSig.

## Motivation

**Limitations.** Organizations sign as groups. A treasury policy reads like "two of the three founders, or one founder plus a majority of the security council". Each group maps to its own MultiSig, and the organization's policy combines those MultiSigs. Sui cannot express this today, because a MultiSig address cannot be a member of another MultiSig.

&nbsp;&nbsp;&nbsp;&nbsp; Flattening each group's members into one MultiSig works for policies that reduce to a single weighted threshold, and many common policies do not. For `(A AND B) OR 2-of-3(X, Y, Z)`, no assignment of weights and threshold is equivalent. Flattening also hits the 10-member limit at three groups of four.

**Workarounds.** Today you have three options for a policy like these:
 1. **Threshold signatures (MPC / TSS).** The inner group jointly holds a single Ed25519 or Secp256k1 key and produces an ordinary signature, which can then be a member of a native MultiSig. The MPC software enforces the inner group's policy off-chain, and on-chain observers cannot tell which members signed.
 1. **Move-level MultiSig.** A shared object holds the assets and capabilities, and its module records approvals from a set of addresses (which may themselves be native MultiSigs). Each action then takes a propose / approve / execute flow across several transactions, the module custodies the objects, and each protocol must write or audit its own governance package.
 1. **Flattening with over-approximation.** Pick a weighted threshold close to the intended policy and accept that it is more or less permissive than intended.

&nbsp;&nbsp;&nbsp;&nbsp; Each option gives up validator enforcement, single-transaction signing, or on-chain auditability.

**Nested MultiSig.** With nested MultiSigs, validators verify any threshold-of-thresholds policy over keys the same way they verify MultiSigs today, in one transaction, with each signer visible on-chain. Users that benefit include:

&nbsp;&nbsp;&nbsp;&nbsp; **Signer Backup Keys.** A signer can hold a primary key and one or more backup keys while taking a single seat in the top-level MultiSig. The signer's keys form an inner 1-of-n MultiSig (n > 1), and that inner MultiSig is one member of the outer MultiSig. Flattening can't express this safely: in a 2-of-3 between Alice, Bob, and Carol, giving Alice's primary and backup keys a weight of 1 each lets Alice reach the threshold alone. With nesting, Alice's 1-of-2 contributes a weight of 1 even if both of her keys sign, so her backups protect against a lost device without adding voting power. The outer address commits to the inner configuration, so Alice chooses her backup keys when the MultiSig is created; changing them later changes the address (see **Rotation**).

&nbsp;&nbsp;&nbsp;&nbsp; **Protocol Treasuries + Upgrade Authorities.** Teams can hold `UpgradeCap`s, admin caps, and treasuries at an address whose policy matches how the organization signs (e.g., an engineering MultiSig AND a security-council MultiSig).

&nbsp;&nbsp;&nbsp;&nbsp; **Custodians + Institutions.** Institutions require policies such as "one approver from operations AND one approver from compliance": two inner MultiSigs under an outer threshold of 2.

&nbsp;&nbsp;&nbsp;&nbsp; **Recovery Paths.** You can pair your everyday key with a recovery MultiSig of guardians, e.g. `OR(user, 3-of-5(guardians))`, where each guardian uses a zkLogin, Passkey, or hardware key.

## Prerequisites

There are no prerequisites for this SIP.

## Specification

This SIP adds a member type to `PublicKey` and `CompressedSignature` that represents an inner MultiSig. The inner MultiSig's **address** identifies the member, and the member's signature is the inner MultiSig's full `MultiSig` struct (signatures, bitmap, and `MultiSigPublicKey`).

**Members.** `PublicKey::MultiSig` holds the 32-byte address of the inner MultiSig. Its flag is the existing MultiSig flag, `0x03`.

**Signatures.** `CompressedSignature::MultiSig` holds the serialized inner `MultiSig` (`0x03 || bcs(MultiSig)`). Validators accept only the current `MultiSig` format and reject `MultiSigLegacy`.

**Addresses.** The outer address derivation does not change. A nested member contributes `0x03 || inner_address || weight` to the outer hash, the same way other members contribute `flag || pk || weight`. `SuiAddress::from(&PublicKey::MultiSig(addr))` returns `addr` as-is.

**Verification.** When the outer MultiSig encounters a `CompressedSignature::MultiSig` at bitmap index `i`:
 1. The member at index `i` must be a `PublicKey::MultiSig`; otherwise verification fails.
 1. The validator deserializes and validates the inner `MultiSig` (`init_and_validate`).
 1. The validator calls the inner `MultiSig`'s existing `verify_claims` with the member's address as the expected address. That call checks that the inner `MultiSigPublicKey` hashes to that address, then verifies the inner signatures against the inner threshold.
 1. On success, the validator adds the member's weight to the outer `weight_sum`.

**Limits.** Validators enforce these limits on each nested MultiSig:
 1. **Depth.** Nesting stops at one level: an inner `MultiSig` must not contain a `PublicKey::MultiSig` member.
 1. **Leaf signatures.** The total number of non-MultiSig signatures verified across the outer and all inner MultiSigs must not exceed `max_multisig_leaf_signatures` (proposed: 20).
 1. **Expensive leaves.** The total number of zkLogin signatures across the outer and all inner MultiSigs must not exceed `max_multisig_zklogin_signatures` (proposed: 10, the maximum a flat MultiSig can reach today).
 1. **Existing limits.** The existing limits apply to each MultiSig (10 members, `u8` weights, `u16` threshold) and to the transaction (`max_tx_size_bytes`).

**Feature gates.** The existing per-scheme gates (`accept_zklogin_in_multisig`, `accept_passkey_in_multisig`, `accept_mldsa65_in_multisig`) and `verify_user_authenticator_epoch` must apply to leaves inside inner MultiSigs as well as to the outer MultiSig.

**Protocol config.** A new feature flag, `accept_multisig_in_multisig`, gates the feature and reaches verification through `VerifyParams`. While the flag is off, validators reject any `MultiSigPublicKey` that contains a `PublicKey::MultiSig` member, whichever members signed. `max_multisig_leaf_signatures` and `max_multisig_zklogin_signatures` become protocol config values.

**Signing flow.** The inner group signs as it does today and combines its partial signatures into an inner `MultiSig` with `MultiSig::combine`. The outer signer wraps that `MultiSig` as a `GenericSignature::MultiSig` and passes it to the outer `MultiSig::combine` like any other member's signature.

## Rationale

**Committing to the inner address.** The alternative design embeds the inner `MultiSigPublicKey` as the member, so the outer `pk_map` holds the full inner configuration. Committing to the inner *address* is better for four reasons:
 1. The outer `MultiSigPublicKey` stays small; each nested member is 32 bytes regardless of the inner group's size.
 1. The verification path matches the one zkLogin and Passkey members use today: the validator checks the member's authenticator against `SuiAddress::from(subsig_pubkey)`.<sup>[8](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-types/src/multisig.rs#L274-L318)</sup>
 1. Sui runs the check that a configuration matches its address on top-level MultiSigs today,<sup>[9](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-types/src/multisig.rs#L127-L132)</sup> and this SIP reuses it unchanged.
 1. The outer configuration lists inner MultiSigs by the addresses users and explorers know them by.

**One level of nesting.** One level covers policies of the form "a threshold over groups", bounds verification cost, and keeps the specification small. A future SIP can allow more depth by relaxing the depth rule; the data format stays the same.

**Rotation.** This SIP does not solve key rotation. A MultiSig address is a hash of its full configuration, so changing an inner group's members changes the inner address and, with it, the outer address. Rotating signers without moving assets requires on-chain account abstraction.

## Backwards Compatibility

**Existing MultiSigs.** This SIP appends the new variants to the end of `PublicKey` and `CompressedSignature`, so the BCS encoding of existing keys, signatures, and MultiSigs does not change. Existing MultiSig addresses do not change either.

**Validators.** Validator binaries without this change cannot decode the new variants. As with ML-DSA-65, the gate must cover *membership* as well as signing: validators must reject a `MultiSigPublicKey` that contains a `PublicKey::MultiSig` member until `accept_multisig_in_multisig` is enabled, even if only non-nested members signed.

**Ecosystem.** SDKs (TypeScript `MultiSigPublicKey`, Rust `sui-types`), `sui keytool`, wallets, explorers, indexers, and GraphQL types that decode MultiSig signatures must handle the new variants. Following `MLDSA65`, the new variants can use `#[schemars(skip)]` to leave the deprecated JSON-RPC spec unchanged.

## Reference Implementation

This SIP changes four files in `sui-types` and one in `sui-protocol-config`. `...` marks unchanged code.

### i. `crates/sui-types/src/crypto.rs`

Append a variant to `PublicKey` and `CompressedSignature`.

```Rust
pub enum PublicKey {
    Ed25519(Ed25519PublicKeyAsBytes),
    Secp256k1(Secp256k1PublicKeyAsBytes),
    Secp256r1(Secp256r1PublicKeyAsBytes),
    ZkLogin(ZkLoginPublicIdentifier),
    Passkey(Secp256r1PublicKeyAsBytes),
    #[schemars(skip)]
    MLDSA65(Box<MLDSA65PublicKeyAsBytes>),
    /// The address of an inner MultiSig.
    #[schemars(skip)]
    MultiSig(MultiSigAddressAsBytes),
}

pub enum CompressedSignature {
    ...
    #[schemars(skip)]
    MLDSA65(Box<MLDSA65SignatureAsBytes>),
    /// `0x03 || bcs(MultiSig)` of an inner MultiSig.
    #[schemars(skip)]
    MultiSig(MultiSigAsBytes),
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct MultiSigAddressAsBytes(pub [u8; SUI_ADDRESS_LENGTH]);

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MultiSigAsBytes(pub Vec<u8>);
```

`PublicKey::flag`, `PublicKey::scheme`, and `AsRef<[u8]>` each gain a matching arm:

```Rust
PublicKey::MultiSig(_) => SignatureScheme::MultiSig, // flag 0x03
...
PublicKey::MultiSig(addr) => &addr.0,
```

### ii. `crates/sui-types/src/base_types.rs`

A nested member's address is the inner MultiSig's address itself, not a hash of it.

```Rust
impl From<&PublicKey> for SuiAddress {
    fn from(pk: &PublicKey) -> Self {
        if let PublicKey::MultiSig(addr) = pk {
            return SuiAddress(addr.0);
        }
        let mut hasher = DefaultHash::default();
        hasher.update([pk.flag()]);
        hasher.update(pk);
        let g_arr = hasher.finalize();
        SuiAddress(g_arr.digest)
    }
}
```

`impl From<&MultiSigPublicKey> for SuiAddress` requires no change: a nested member contributes `0x03 || inner_address || weight`.

### iii. `crates/sui-types/src/multisig.rs`

#### iiia. Gating + limits in `verify_claims`

```Rust
if self.multisig_pk.has_multisig_member() && !verify_params.accept_multisig_in_multisig {
    return Err(SuiErrorKind::InvalidSignature {
        error: "MultiSig member not supported inside multisig".to_string(),
    }
    .into());
}

// Depth 1: an inner MultiSig may not itself contain MultiSig members.
if verify_params.is_nested_multisig && self.multisig_pk.has_multisig_member() {
    return Err(SuiErrorKind::InvalidSignature {
        error: "Nested multisig depth exceeded".to_string(),
    }
    .into());
}

let (leaf_sigs, zklogin_sigs) = self.count_leaf_sigs()?;
if leaf_sigs > verify_params.max_multisig_leaf_signatures
    || zklogin_sigs > verify_params.max_multisig_zklogin_signatures
{
    return Err(SuiErrorKind::InvalidSignature {
        error: "Too many signatures in nested multisig".to_string(),
    }
    .into());
}
```

#### iiib. New arm in the verification loop

```Rust
CompressedSignature::MultiSig(bytes) => {
    if !matches!(subsig_pubkey, PublicKey::MultiSig(_)) {
        return Err(SuiErrorKind::InvalidSignature {
            error: "Invalid sig for pk error=signature/pubkey type mismatch".to_string(),
        }
        .into());
    }
    let inner = MultiSig::from_bytes(&bytes.0).map_err(|_| {
        SuiErrorKind::InvalidSignature {
            error: "Invalid inner multisig bytes".to_string(),
        }
    })?;
    inner
        .verify_claims(
            value,
            SuiAddress::from(subsig_pubkey),
            &verify_params.nested(),
            zklogin_inputs_cache.clone(),
        )
        .map_err(|e| FastCryptoError::GeneralError(e.to_string()))
}
```

`verify_params.nested()` returns a copy of `VerifyParams` with `is_nested_multisig = true`, so that the inner call enforces the depth rule and re-applies every existing per-scheme gate to the inner leaves.

#### iiic. Recursive epoch checks

`verify_user_authenticator_epoch` checks only the outer MultiSig's zkLogin signatures today, and carries a `TODO: call this on all sigs to avoid future lapses`.<sup>[10](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-types/src/multisig.rs#L86-L96)</sup> It must recurse into inner MultiSigs.

```Rust
fn verify_user_authenticator_epoch(
    &self,
    epoch_id: EpochId,
    max_epoch_upper_bound_delta: Option<u64>,
) -> Result<(), SuiError> {
    self.get_zklogin_sigs()?.iter().try_for_each(|s| {
        s.verify_user_authenticator_epoch(epoch_id, max_epoch_upper_bound_delta)
    })?;
    self.get_inner_multisigs()?.iter().try_for_each(|m| {
        m.verify_user_authenticator_epoch(epoch_id, max_epoch_upper_bound_delta)
    })
}
```

### iv. `crates/sui-types/src/signature.rs`

`GenericSignature::to_public_key` and `GenericSignature::to_compressed`<sup>[11](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-types/src/signature.rs#L159-L266)</sup> reject a `GenericSignature::MultiSig` today, so `MultiSig::combine` cannot accept an inner MultiSig as a partial signature.

```Rust
pub fn to_public_key(&self) -> Result<PublicKey, SuiError> {
    match self {
        ...
        GenericSignature::MultiSig(m) => Ok(PublicKey::MultiSig(MultiSigAddressAsBytes(
            SuiAddress::from(m.get_pk()).to_inner(),
        ))),
        ...
    }
}

pub fn to_compressed(&self) -> Result<CompressedSignature, SuiError> {
    match self {
        ...
        GenericSignature::MultiSig(m) => {
            Ok(CompressedSignature::MultiSig(MultiSigAsBytes(m.as_ref().to_vec())))
        }
        ...
    }
}
```

### v. `crates/sui-protocol-config/src/lib.rs`

```Rust
// If true, a MultiSig may be a member of another MultiSig.
#[serde(skip_serializing_if = "is_false")]
accept_multisig_in_multisig: bool,

...

// Maximum number of leaf (non-MultiSig) signatures verified across a nested MultiSig.
max_multisig_leaf_signatures: Option<u64>,
// Maximum number of zkLogin signatures verified across a nested MultiSig.
max_multisig_zklogin_signatures: Option<u64>,
```

Following precedent, Mysten enables the flag on devnet first, then testnet, then mainnet, each in a later protocol version.

## Security Considerations

**Verification cost.** Validators verify signatures before execution and do not charge gas for them. Without limits, one level of nesting allows 10 × 10 = 100 leaf signatures per transaction, and each could be a zkLogin Groth16 proof. The depth rule and the two signature limits cap this at 2× the leaf signatures and 1× the zkLogin proofs a flat MultiSig allows today. Validators must check these limits *before* verifying any signature.

**Feature-gate bypass.** The existing gates (`has_zklogin_sigs`, `has_passkey_sigs`, `has_mldsa65_member`) inspect the MultiSig they run on and nothing below it. If a validator verified an inner MultiSig through any path other than its own `verify_claims`, an attacker could slip a disabled scheme in as a leaf of that inner MultiSig. The specification requires each gate to apply at every depth, and the reference implementation verifies inner MultiSigs through `verify_claims` with `VerifyParams` derived from the outer call.

**zkLogin expiry.** Validators must check `max_epoch` on zkLogin signatures inside inner MultiSigs. Without the recursive `verify_user_authenticator_epoch`, an expired ephemeral key could keep signing for a nested MultiSig with no end date.

**Type confusion.** Validators must accept a `CompressedSignature::MultiSig` only against a `PublicKey::MultiSig` member, and the reverse. The new arm runs the signature/pubkey mismatch check from `additional_multisig_checks` whether or not that flag is set.

**Replay.** Inner signers sign the same intent message as the outer MultiSig. That message includes the full `TransactionData`, sender included (the outer address). Nobody can reuse an inner MultiSig's signature for a transaction sent by the inner address or by a different outer MultiSig.

**Misconfiguration.** If a `PublicKey::MultiSig` member holds an address that is not a MultiSig (e.g., an Ed25519 address), that member can't sign, because no `MultiSigPublicKey` hashes to it. Its weight is dead and may put the outer threshold out of reach. Wallets and SDKs that build nested MultiSigs should require the inner `MultiSigPublicKey` at creation time and derive the address from it.

**Overlapping members.** A leaf key may appear in the outer MultiSig and inside an inner MultiSig, or in several inner MultiSigs. Each occurrence contributes its own weight. The outer address commits to the full configuration, so anyone can see the overlap on-chain; wallets should show it to users.

## References

1. [[Sui Repo] mainnet-v1.82.3](https://github.com/MystenLabs/sui/tree/bf4073918ed33cfa0b09c500658fa116a774bcfd)
1. [[Sui Repo] `MultiSigPublicKey`](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-types/src/multisig.rs#L546-L551)
1. [[Sui Repo] MultiSig address derivation](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-types/src/base_types.rs#L988-L1008)
1. [[Sui Repo] `PublicKey`](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-types/src/crypto.rs#L281-L292)
1. [[Sui Repo] `CompressedSignature`](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-types/src/crypto.rs#L1878-L1887)
1. [[SIPs] SIP-9: Passkey](https://github.com/sui-foundation/sips/blob/main/sips/sip-9.md)
1. [[Sui Repo] MultiSig protocol feature flags](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-protocol-config/src/lib.rs#L664-L670)
1. [[Sui Repo] zkLogin + Passkey member verification](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-types/src/multisig.rs#L274-L318)
1. [[Sui Repo] MultiSig address check](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-types/src/multisig.rs#L127-L132)
1. [[Sui Repo] `MultiSig::verify_user_authenticator_epoch`](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-types/src/multisig.rs#L86-L96)
1. [[Sui Repo] `GenericSignature::to_compressed` + `to_public_key`](https://github.com/MystenLabs/sui/blob/bf4073918ed33cfa0b09c500658fa116a774bcfd/crates/sui-types/src/signature.rs#L159-L266)

## Copyright

[CC0 1.0](../LICENSE.md).
