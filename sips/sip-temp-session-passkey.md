| SIP-Number          | <Leave this blank; it will be assigned by a SIP Editor> |
| Title               | Passkey Session based signature scheme support |
| Description         | This SIP proposes the addition of passkey session based signature scheme to enable transaction signing using passkey authenticators, but without human interaction for every transaction. |
| Author              | Joy Wang <joy@mystenlabs.com> |
| Editor              | <Leave this blank; it will be assigned by a SIP Editor> |
| Type                | Standard |
| Category            | Core |
| Created             | 2024-07-24 |
| Comments-URI        | <Leave this blank; it will be assigned by a SIP Editor> |
| Status              | <Leave this blank; it will be assigned by a SIP Editor> |
| Requires            | N/A (Related to SIP-9) |

## Abstract

This SIP proposes the addition of a passkey session signature scheme to make it possible to sign transactions using passkeys, but without human approvals (FaceID, TouchID, etc) for every transaction at signing. This is a more UX friendly alternative to the passkey scheme proposed in SIP-9 for some applications. On a high level, to construct a session based passkey signature, the user is only prompted once to register an ephemeral key with a certain expiry epoch. The ephemeral key is stored in the frontend, and can be used to sign any transactions within epoch expiry, without re-authenticating with the passkey device. 

## Motivation

While passkey is known for enhanced security that requires user approval for each transaction, it is burdensome for users to authenticate with the passkey device every time for some applications, especially for games and social apps that weigh more over the smoother user experience. Here we propose an alternative for a session based passkey authenticator. It is up to the application to choose between passkey authenticator and its session based variation based on their considerations. 

SIP-9 discusses the benefits and overall flow for passkey. Here we focus on the difference between passkey authenticator and passkey session authenticator. 

## Specification

A new `passkey_session` signature scheme is introduced that allows clients to construct transaction signatures using passkey session authenticators.

### Signature encoding

The passkey session signature is serialized with the following `BCS` structure and prepended with a flag for passkey session authenticator `0x07`. 

```typescript
    bcs.registerStructType('PasskeySessionAuthenticator', {
        authenticatorData: [BCS.VECTOR, BCS.U8],
        clientDataJson: [BCS.VECTOR, BCS.U8],
        maxEpoch: BCS.U64,
        registerSignature: [BCS.VECTOR, BCS.U8],
        ephemeralSignature: [BCS.VECTOR, BCS.U8]
    })
  
    // encodes the struct in bcs and prepend with a flag 0x07
    export function encodePasskeySignature(
        authenticatorData: Uint8Array,
        clientDataJSON: Uint8Array,
        registerSig: Uint8Array,
        ephSig: Uint8Array
    ) {
        let bytes = bcs
        .ser('PasskeyAuthenticator', {
            authenticatorData: authenticatorData,
            clientDataJson: clientDataJSON,
            registerSignature: registerSig,
            ephemeralSignature: ephSig
        })
        .toBytes();

        const sigBytes = new Uint8Array(1 + bytes.length);
        sigBytes.set([0x07]);
        sigBytes.set(bytes, 1);
        return sigBytes;
    }
```

`PasskeySessionAuthenticator` is defined as one of `GenericSiganture` according to [crypto agility](https://mystenlabs.com/blog/cryptography-in-sui-agility). A flag byte is defined during serialization indicating the signature scheme. This is set to `0x07` for `PasskeySessionAuthenticator`. Once deserialized as a passkey session authenticator, the verification logic is executed as described in the next section. 

`authenticatorData` is a byte array that encodes [Authenticator Data](https://www.w3.org/TR/webauthn-2/#sctn-authenticator-data) structure returned by the authenticator attestation response as is (byte array of 37 bytes or more). Its contents are not relevant here but it's required for signature verification.

`clientDataJson` is a byte array that is a JSON-compatible UTF-8 encoded serialization of the client data which is passed to the authenticator by the client during the authentication request (see [CollectedClientData](https://www.w3.org/TR/webauthn-2/#dictdef-collectedclientdata)). It contains (among other fields) the `challenge` field which is the `base64url` URL encoded `flag_eph_pk || eph_pk || max_epoch` that was passed in by the client to the authenticator. This field needs to be parsed in order to verify that the signature has been produced over the byte array encoded for `flag_eph_pk || eph_pk || max_epoch`.

`registerSignature` is a byte array that encodes `flag || sig_bytes || pk_bytes`. This is the signature returned by passkey that commits over the ephemeral public key and its max epoch. The `flag` indicates the flag of the signature scheme (currently it is required to be `secp256r1`'s signature scheme `0x02`). Both the signature and public key should be converted from DER format in passkey authenticator response to the compact format and with the requirements specified below:

- `sig_bytes` is the signature bytes produced by the authenticator. It is 64 bytes long and is encoded as a simple concatenation of two octet strings `r || s` where `r` and `s` are 32-byte big-endian integers. The signature must have its `s` in the lower half of the curve order. If s is too high, it is required to convert `s` to `order - s` where curve order is `0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551` defined [here](https://secg.org/SEC2-Ver-1.0.pdf). 

- `pk_bytes` is the public key bytes in compacted format as 33 bytes. This is derived from the public key returned from passkey registration.

`ephemeralSignature` is a byte array that encodes `eph_flag || eph_sig_bytes || eph_pk_bytes`. The `eph_flag` indicates the flag for the ephemeral signature scheme, currently Ed25519, Secp256k1 and Secp256r1 are supported. Both the signature and public key should be encoded according to the specification of its signature scheme. 

### Signature verification

The signature verification is performed by the Sui validators using the following algorithm. This is implemented as a Sui protocol change with `trait AuthenticatorTrait`. 

1. Check the `flag` byte as `0x07`, then deserialize it as `PasskeySessionAuthenticator`.
2. Validate the `clientDataJSON` to be well formed. That is, it can be deserialized with struct [`CollectedClientData`](https://github.com/1Password/passkey-rs/blob/main/passkey-types/src/webauthn/attestation.rs#L581) with required fields such as `type`, `origin`, `crossOrigin`, `challenge` and allows for arbitrary additional fields. The `type` field must be `webauthn.get`, and the `challenge` must be decoded successfully with `base64url` into a byte array. If not, reject the signature.
3. Verify that the decoded `challenge` byte array equals to `flag_eph_pk || eph_pk || max_epoch` derived from the transaction. If not, reject the signature.
4. Verify the sender of the transaction is derived correctly as `blake2b_hash(flag_passkey || pk_passkey)`. If not, reject the signature.
5. If the current epoch is larger than `maxEpoch` (this means the registered ephemeral key expires), reject the signature. 
6. Verify the signature and public key in `ephemeralSignature` with respect to its signature scheme, where the message as `intent || blake2b_hash(tx_data)`. If verification fails, reject the signature.
7. If the `flag` in `registerSignature` is not `secp256r1`, reject the signature. 
8. Verify the signature and public key in `registerSignature` with the secp256r1 ECDSA algorithm using the constructed message as `authenticatorData || sha256(clientDataJSON)`. If verification fails, reject the signature.

### Passkey wallet creation

The public key is returned to frontend upon credential creation (`navigator.credentials.create`). A passkey address is defined as `blake2b_hash(flag_passkey_session || pk_passkey)` where the flag_passkey_session is `0x07`.

### Transaction signing using Passkey Session

To sign a transaction using passkey, the client first generates an ephemeral keypair of any signature scheme (currently we support Ed25519, Secp256k1 and Secp256r1) in the application frontend, then make an [`assertion`](https://www.w3.org/TR/webauthn-2/#authenticatorgetassertion) request to the authenticator where the [`challenge`](https://www.w3.org/TR/webauthn-2/#dom-publickeycredentialrequestoptions-challenge) is set to the bytearray `flag_eph_pk || eph_pk || max_epoch`. The passkey signature `registerSignature` commits over the ephemeral public key and max epoch. 

Then the frontend can sign transactions with the ephemeral key over the transaction itself to produce `ephemeralSignature`.

By serializing `authenticatorData`, `clientDataJson`, `maxEpoch`, `registerSignature`, `ephemeralSignature` into `PasskeySessionSignature`, users can now submit it encoded as described above for transaction execution. 

As long as the current epoch is within the max epoch in the signature at submission, the ephemeral key can be reused and sign many transactions, and the same `registerSignature` can be used. 

## Rationale

Instead of having the passkey to sign over the transaction, the passkey is only required to commit to an ephemeral public key and a max epoch that the ephemeral key is valid for. The ephemeral signature is still required to commit over the transaction. 

This way we can ensure that an ephemeral key is registered with the passkey for a duration with user authentication, while each transaction requires signing with an ephemeral key, but without passkey device interaction. 

### Public key recovery

One of the inconveniences of using the WebAuthn standard for this use case is that the public key for the passkey is only returned to the client upon registration but not during signing.

Therefore, it is recommended for wallets to persist the public key as a state. During recovery flow or registering a new device, the client can make a regular WebAuthn assertion request to get a signature and the client can recover the public key and the passkey Sui address. Since `ECDSA` public key recovery can produce up to 4 valid public keys for a signature, two assertion requests are required to determine the only one possible public key by comparing the two sets of recovered public keys. 

## Backwards Compatibility

The signature scheme is enabled under the domain separated flag 0x07. There are no issues with backwards compatibility with other signature schemes. 

## Reference Implementation

Forked repo with implementation for Sui transaction construction and signing in [frontend](todo) against localnet ran against this [PR](todo).

## Security Considerations

The origin which a passkey is attached to needs to be carefully considered. Since any process or extension that has access to the origin can initiate a passkey assertion request, the origin always needs to be in a trusted sandbox environment such as a stand alone application, browser wallet extension, or mobile app. If the passkey is tied to an origin that is not in a trusted environment it can be susceptible to wallet impersonation attacks.

The ephemeral key must be randomly generated upon expiry. Reusing the same ephemeral key will likely lead to the compromise of the passkey wallet, since the compromised ephemeral key can sign arbitrary transactions along with the same passkey `registerSignature`. 

## Copyright

[CC0 1.0](../LICENSE.md).