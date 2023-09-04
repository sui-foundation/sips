| SIP-Number          | 9 |
| ---:                | :--- |
| Title               | WebAuthn signature scheme support |
| Description         | This SIP proposes the addition of WebAuthn signature scheme to enable transaction signing using WebAuthn authenticators (passkeys). |
| Author              | Krešimir Klas <kklas@kunalabs.io, @kklas>, Kostas Chalkias <kostas@mystenlabs.com, @kchalkias> |
| Editor              | Will Riches <will@sui.io, @wriches> |
| Type                | Standard |
| Category            | Core |
| Created             | 2023-08-01 |
| Comments-URI        | https://sips.sui.io/comments-9 |
| Status              | Draft |
| Requires            | |

## Abstract

This SIP proposes the addition of WebAuthn signature scheme to make it possible to sign transactions using WebAuthn authenticators / passkeys. While the `secp256r1` signature scheme, which is widely used by WebAuthn authenticators including Yubikeys, Android phones, iPhones, and MacBooks, is available on Sui, the WebAuthn standard doesn't allow for arbitrary message signing and the signed payload includes additional data which makes it incompatible with the `secp256r1` signature scheme on Sui. Therefore, in order to be able to verify transaction signatures produced by the WebAuthn authenticators, a new signature scheme needs to be introduced that can verify signatures of this format. WebAuthn signature support would make Sui more accessible to non-advanced users as it can simplify key management and allows for web2-like flows that users are already familiar with.

## Motivation

### WebAuthn overview

WebAuthn is a W3C standard for passwordless authentication that is supported by all major browsers and operating systems. It is also supported by many hardware devices including Yubikeys, Android phones, and iPhones.

On a high level it works as follows. A digital credential based on public key cryptography (also known as passkey) is created during the registration process and stored on the authenticator (e.g., security key, phone, laptop...). After registration, the authenticator can be used to authenticate the user by signing a challenge provided by the server. Passkeys are often synchronized between user's devices from the same ecosystem using the cloud (with e2e encryption). This makes it possible to use the same passkey on multiple devices and to recover the passkey in case the devices are lost. However, passkeys can also be confined to a single device such as a physical security key.

Passkeys are secure and privacy-preserving. For every registration, a new passkey is created on the authenticator which is tied to and only accessible by the origin (app, website...) that initiated the registration. This prevents the origin from tracking the user across different websites and apps. Passkeys are discoverable which means it's possible for the origin to make an authentication request without knowing any identifiers before hand. This allows for password-less, username-less authentication flows. WebAuthn prevents phishing by requiring the authenticator to be in physical proximity to the device where the authentication is initiated. Authenticators that are part of the client device are refered to as *platform authenticators*, while those that are reachable via cross-platform transport protocols ("usb", "nfc", and "ble") are referred to as *roaming authenticators*.

The wide variety of usage modalities and form factors of WebAuthn authenticators makes it possible to design authentication flows that are both secure and convenient for the user. For example, a user can use a passkey stored on their phone to authenticate on a desktop browser by scanning a QR code produced by the browser. The QR code contains BLE pairing information that allows the phone to communicate with the browser over a secure channel and sign the authentication challenge. The BLE pairing is done seamlessly in the background without the user having to manually pair the devices. A video demonstration of this flow can be found [here](https://youtu.be/7UI1T-CwJN8?t=19) and a website to try it out can be found [here](https://webauthn.io/).


### WebAuthn for Sui

Wallets and key management are a major usability hurdle and an obstacle for mainstream adoption of crypto. By enabling WebAuthn on Sui key management can be simplified. With WebAuthn, users don't have to manually manage and secure their private keys or seed phrases. Instead, they can use a passkey that is securely stored on their device. If the device is cloud-enabled, the passkey can be synchronized between the user's devices. This makes it possible to use the same address on multiple devices without having to manually import the private key or seed phrase which is prone to phishing attacks and key leaks. It also makes it possible to recover the passkey in case the device is lost.

Furthermore, since the private keys are stored on the device itself, it opens up the possibility of being able to use Sui without having to install a wallet extension or a mobile app first. One could, for example, implement a backend-less wallet web app that uses WebAuthn to sign transactions. This wallet would be served from a website and upon registration it would ask the user to create a passkey on their device. Web3 apps can then be used as usual, and upon requesting a transaction, a browser pop-up window of the wallet app would open and ask the user to review the transaction and sign it with their passkey. The wallet browser app can be fully stateless in that it doesn't have to store any private keys or seed phrases. And if the user's passkey is synced through the cloud on their other devices, they can use the same wallet on multiple devices without having to manually import the private key or seed phrase. Additionally, since the cloud also handles the passkey backups, the user doesn't have to worry about losing access to their wallet if their device is lost. This approach would work well both on mobile and desktop.

In the user doesn't fully trust the cloud with key management, one could, for example, employ a multisig address with 2 of 4 threshold such that:
- the cloud-synced passkey on a phone has weight 1
- a security key (e.g., Yubikey) passkey has weight 1
- a hardware wallet has weight 2

In this case, the seamless user experience is preserved as the transactions can be easily signed using the phone passkey and the security key (either over usb or nfc) together, while at the same time the cloud-synced passkey doesn't have to be fully trusted as it can't sign transactions on its own. And in case either the security key, phone, or the hardware wallet is lost, the address can be recovered by using the remaining 2 devices.

In conclusion, the motivation for integrating WebAuthn into Sui is multifold. It offers an opportunity to address key pain points in the current user experience, namely the complexities associated with key management. By simplifying these processes, WebAuthn can drastically enhance the user experience and, ultimately, help drive the mainstream adoption of Sui. This ultimately demonstrates how the integration of WebAuthn can make Sui not just more secure, but more accessible.

### Example flows

This section describes a few relevant (out of multitudes possible) transaction signing flows enabled by WebAuthn. Since WebAuthn is widely supported by all of the major platforms (including Windows, Android, iOS, and macOS), the user is *not* required to install any additional software, apps, browser extensions, or middleware for the flows described here.

#### Flow (A) - desktop browser + phone cross-platform authentication

This flow describes how a user can use a passkey stored on their phone to sign a transaction initiated on a desktop browser. The passkey is protected by a PIN or biometrics and is securely stored on the phone. Additionally, the passkey is securely backed up on the cloud and can be synchronized between the user's devices.

The figure below describes the flow. A transaction is initiated by a web3 app which opens a pop-up window of the wallet web app (as described in the previous section) or browser extension. When the user reviews and approves the transaction (fig. A.1), the browser creates a pop-up window with a QR code (fig. A.2). The user then scans the QR code with their phone (fig. A.3). The phone will then require the user to authenticate using a pin or biometrics (fig. A.4). When the user authenticates, the transaction will be signed by the passkey and the signature passed over to the desktop browser (A.5). The wallet app running in the browser will then broadcast the transaction to the blockchain.

![Flow A](../assets/sip-webauthn/flow-a.png)

#### Flow (B) - desktop browser + security key cross-platform authentication

This flow describes how a user can use a security key (e.g., Yubikey) to sign a transaction initiated on a desktop browser. The passkey is stored on the security key and is protected by a PIN or biometrics. Once the passkey is generated on the security key, it can never leave the device and it's not possible to back it up. It's advised to only use this method in a multisig setup where the security key is only one of the possible signers because if the security key is lost the account can't be recovered.

The figure below describes the flow. A transaction is initiated by a web3 app which opens a pop-up window of the wallet web app (as described in the previous section) or browser extension. When the user reviews and approves the transaction (fig. B.1), the browser creates a pop-up prompting the user to authenticate using their security key (fig. B.2). In case the security key doesn't support biometrics, the user will be required to enter their PIN (fig. B.3). The user then authenticates by touching the security key (fig. B.4), and in case the security key supports biometrics, user's fingerprint is scanned. The transaction will then be signed by the passkey stored on the security key and the signature passed over to the desktop browser. The wallet app running in the browser will then broadcast the transaction to the blockchain.

![Flow B](../assets/sip-webauthn/flow-b.png)

#### Flow (C) - platform authentication

This flow describes how a user can use a passkey to sign a transaction initiated on the same device. This flow is similar to flow (A) but without the intermediate step of scanning the QR code. It is possible on platforms that natively support passkey management (e.g., Android, iOS, macOS, Windows).

The figure below describes how a user would use their phone to sign a transaction initiated in a browser on the same phone. A transaction is initiated by a mobile app or web app which opens a pop-up window of a wallet web app. When the user reviews and approves the transaction (fig. C.1), the phone creates a pop-up window requiring the user to authenticate using a pin or biometrics (fig. C.2). When the user authenticates, the transaction will be signed by the passkey and the signature passed over back to the wallet web app (C.3). The wallet app will then broadcast the transaction to the blockchain.

![Flow C](../assets/sip-webauthn/flow-c.png)

## Specification

A new `webauthn` signature scheme is introduced that allows clients to construct transaction signatures using WebAuthn authenticators. Although the WebAuthn supports multiple signature algorithms, only the `secp256r1` algorithm is supported by Sui.

### Signature encoding

`webauthn` signatures are encoded with the following `BCS` structure:

```rust
struct WebAuthnSignature {
    flag: u8,
    authenticatorData: Vec<u8>,
    clientDataJSON: String,
    signature: [u8; 64],
    pubkey: [u8; 33],
}
```

`flag` is the signature scheme discriminator byte. In the case of `webauthn`, it is always set to `0x6`.

`authenticatorData` contains the value of the encoded [Authenticator Data](https://www.w3.org/TR/webauthn-2/#sctn-authenticator-data) structure returned by the authenticator attestation response as is (byte array of 37 bytes or more). Its contents are not relevant here but it's required for signature verification.

`clientDataJSON` contains a JSON-compatible UTF-8 encoded serialization of the client data which is passed to the authenticator by the client during the authentication request (see [CollectedClientData](https://www.w3.org/TR/webauthn-2/#dictdef-collectedclientdata)). It contains (among other fields) the `challenge` field which is the `base64url` URL encoded TX digest that was passed in by the client to the authenticator. This field needs to be parsed in order to verify that the signature has been produced for the correct TX digest. Other fields are not used here.

`signature` contains the `secp256r1` signature produced by the authenticator. It is 64 bytes long and is encoded as a simple concatenation of two octet strings `r || s` where `r` and `s` are 32-byte big-endian integers (i.e., `ASN.1 DER` format).

`pubkey` contains the `secp256r1` public key of the credential (passkey) that produced the signature encoded in the `X9.62` compressed format (33 bytes).

Additionally, the encoded signature is capped to a max length of `MAX_LEN` bytes.

### Signature verification

The signature can be verified using the following algorithm:

1. Make sure that the `flag` byte is set to `0x6`. If not, reject the signature.
2. Verify that the encoded signature length is at most `MAX_LEN` bytes. If not, reject the signature.
3. Parse the encoded signature using the `BCS` encoding using the structure described above.
4. Parse the `clientDataJSON` field and extract the `challenge` field.
5. Verify that the `challenge` field matches the expected TX digest. If not, reject the signature.
6. Verify the signature with the secp256r1 ECDSA algorithm using the constructed message `authenticatorData || sha256(clientDataJSON)`, the `signature`, and the `pubkey`. If verification fails, reject the signature.

### Transaction signing using WebAuthn

To sign a transaction using WebAuthn, the client needs to make an [assertion](https://www.w3.org/TR/webauthn-2/#authenticatorgetassertion) request to the authenticator using the transaction digest (`blake2b` hash over the BCS encoded transaction data) as the [challenge](https://www.w3.org/TR/webauthn-2/#dom-publickeycredentialrequestoptions-challenge).

The signature is encoded as described above.

## Rationale

While WebAuthn supports multiple different signature schemes, including ed25519, only the `secp256r1` scheme has wide support across different authenticators with other schemes having limited support on some security keys. Therefore it makes sense to support only the `secp256r1` scheme on Sui.

The `secp256r1` signature scheme is already supported on Sui. However, the `secp256r1` scheme on Sui requires that the signature is produced over the transaction digest. This is incompatible with the signatures produced by WebAuthn authenticators as they include additional data in the signature payload. Therefore, a new signature scheme needs to be introduced that can verify signatures produced by WebAuthn authenticators.

When a client makes an assertion (authentication) request to a WebAuthn authenticator, it is able to pass in an arbitrary `challenge` byte array. The passed-in `challenge` is then included in the signature payload alongside other data. The WebAuthn signature is produced over `authenticatorData || sha256(clientDataJSON)` where [authenticatorData](https://www.w3.org/TR/webauthn-2/#sctn-authenticator-data) is the authenticator data returned by the authenticator and [clientDataJSON](https://www.w3.org/TR/webauthn-2/#dictdef-collectedclientdata) is the JSON-serialized client data passed in by the client which also includes the `challenge`.

In the case of Sui transaction signing, the client would pass in the transaction digest as the `challenge`. This makes it possible for the nodes / validators to verify that the signature has been produced for the correct transaction. However, because the signature is produced over `authenticatorData || sha256(clientDataJSON)`, `authenticatorData` and `clientDataJSON` also need to be included in the signature payload. Furthermore, it is not possible to send only `sha256(clientDataJSON)` because `clientDataJSON` needs to be parsed in order to verify that it contains the correct `challenge`.

However, the data contained within `authenticatorData` and `clientDataJSON`, aside from the `challenge`, is not itself relevant to Sui, and having to pass in this data is overhead.

In case of `authenticatorData`, we can expect its size to be 37 bytes. It can possibly be more in case the optional `extensions` field is used, but this is not expected to be the case. The optional `attestedCredentialData` field is never used in assertion requests. For more details see the [reference](https://www.w3.org/TR/webauthn-2/#sctn-authenticator-data).

`clientDataJSON` contains 4 mandatory fields -- `type`, `challenge`, `origin`, and `crossOrigin`, and the client is allowed to arbitrarily add additional fields. The `type` field is always set to `webauthn.get` for assertion requests. The `challenge` is `base64url` encoded transaction digest byte array. The `origin` is the fully qualified [origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) of the requester, and `crossOrigin` is a boolean flag. Therefore, the size of `clientDataJSON` will vary largely based on the size of the `origin` and the presence of any additional fields, but we can expect it to average at around 150 bytes.

Therefore, we can roughly expect the total size of the encoded signature to be around 285 bytes on average (`1 + >=37 + ~150 + 64 + 33`), with ~187 bytes of overhead (`>=37 + ~150`).

Arguably, since the `clientDataJSON` encoding algorithm is more strictly defined ([reference](https://www.w3.org/TR/webauthn-2/#clientdatajson-serialization)), it would be possible to only send the `origin` and `crossOrigin` fields (and any extra fields) and reconstruct the `clientDataJSON` on the backend. However, since JSON encodings are not canonical, and even though the `clientDataJSON` encoding algorithm is more strictly defined, it is still possible for the client to send in a different encoding. Furthermore, the WebAuthn specification [notes](https://www.w3.org/TR/webauthn-2/#dictionary-client-data) that "it’s critical when parsing to be tolerant of unknown keys and of any reordering of the keys". So in order to avoid any potential compatibility issues in the future, it is better to send the `clientDataJSON` as is.

Due to these reasons, the `clientDatJSON` and `authenticatorData` fields are defined as variable length in the `WebAuthnSignature` BCS encoding. Additionally, in order to avoid any abuse, the encoded signature is capped to max length of `MAX_LEN` bytes.

### Public key recovery

One of the inconveniences of using the WebAuthn standard for this use case is that there's no way to recover the public key from the authenticator after the registration. This is because, in normal WebAuthn flows, the public key is expected to be persisted on the website backend when a new authenticator credential is registered. This means that the "stateless" wallet described in the motivation section where the wallet can be fully recovered by just possessing the passkey would not be possible.

Luckily though, with the `ECDSA` signature scheme it is possible to recover the public key from the signature and the message it signs. This means that the wallet public key can be recovered through a regular WebAuthn assertion request. However, `ECDSA` public key recovery can produce up to 4 valid public keys for a signature, and it's not possible to tell which one corresponds to the private key that signed the transaction. But this can be resolved by doing a second assertion request to produce another signature and doing recovery on it as well. Comparing the two sets of recovered public keys, there will be only 1 public key that is common to both sets. This public key is the one that corresponds to the private key on the authenticator. Therefore, the wallet can be fully recovered by possessing just the passkey and no additional data.


## Backwards Compatibility

There are no issues with backwards compatibility.

## Security Considerations

None.

## Copyright

[CC0 1.0](../LICENSE.md).