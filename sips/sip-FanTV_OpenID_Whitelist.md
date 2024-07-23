|   SIP-Number | N/A |
| -----------: | :--------------------------------------------------- |
|        Title | Add FanTV as a zkLogin OpenID provider |
|  Description | Add FanTV as a whitelisted OpenID provider enabled for zkLogin on Sui to provide logging with phone numbers to create Sui wallet. |
|       Author |  Jaswant Kumar <@jaswant25, jaswant.kumar@fantv.in>, Joy Wang <joy@mystenlabs.com> |
|       Editor | N/A |
|         Type | Standard |
|     Category | Core |
|      Created | 2024-06-07 |
| Comments-URI | N/A |
|       Status | N/A |
|     Requires | N/A |

## Abstract

Currently no providers enabled on Sui support login with a phone number. Phone number log in is a dominant credential option in many sectors and having such a provider for zkLogin is crucial for mass adoption of zkLogin. Here we propose to add FanTV as a OpenID provider on Sui that enables login with phone number. This will onboard FanTV users to Sui seamlessly and also allows users for other Sui applications with simply a phone number. 

## Motivation

Phone number log in is a dominant credential option in many markets. Having such a provider for zkLogin is crucial for mass adoption for Sui. This allows anyone with a phone number to create a wallet on Sui and interact with dApps. 

## Specification

FanTV is fully compatible with the current [OpenID specification](https://openid.net/specs/openid-connect-core-1_0.html) with the following configurations:

todo: fill out the form below. example well known config: https://accounts.google.com/.well-known/openid-configuration, example jwk endpoint: https://www.googleapis.com/oauth2/v3/certs, example issuer: "https://accounts.google.com"

|             Item          | Endpoint  | Example Content | 
|-------------------------- |-----------|-----------------|
| Well known configuration  |https://accounts.fantv.world/.well-known/openid-configuration |                 |
| JWK endpoint              |https://fantv-apis.fantiger.com/v1/web3/jwks.json |                 |
| Issuer                    |https://accounts.fantv.world |                 |
| Authorization link        |https://fantv-apis.fantiger.com/v1/oauth2/auth|                 |
| Allowed Client IDs        |r24bskxyafwwua68et2wmuqeyoa.apps.fantv.world|                 | 

## JWK rotation details

 It's configurable - currently it's on monthly basis ( We can configure this based upon security measures and operational overhead in future) 

## JWK endpoint availability

Current end point is always available, its deployed on highly scalable servers , running on multiple geo-location based servers and we have implemented alerting systems for continuous monitoring.

## Signing key storage details

We are using AWS HSM model to store the private key.

## Claims 

Is there any other custom claims supported by the payload in addition to `sub`, `aud`, `nonce`? If so, what are they and is there a maximum length and type check enforced? (i.e. it is not possible to pass in a JSON format with nested claims inside). 

Yes, sub field is unique. The user ID is derived from the object ID of a single MongoDB instance to ensure uniqueness.
Aud & nonce both fields are supported, type is string, nonce doesn't have a fixed length and aud is an URL identifier

## Rationale

JWT signing key rotation is an important security practice. Here are the key reasons why it's mandatory:

Mitigation of Key Compromise Risks, Compliance with Security Policies and Standards, Expiration and Revocation Management

AWS HSM module is the best industry solution for storing keys securely and for signing JW payloads securely. Rotation is to maintain safety and the frequency is subjective of operational overheads.


## Backwards Compatibility

ZkLogin wallets are domain separated by the OpenID issuer and its client ID. There is no backward compatibility issue with existing issuers. 

Once the SIP is finalized with the configurations defined above (issuer string, client ID etc), they will not change again. Otherwise, the wallet created based on this configuration will result in lost of fund. 

## Test Cases

eyJ0eXAiOiJqd3QiLCJhbGciOiJSUzI1NiIsImtpZCI6Ik81cnl4Ri16TUNMbVM2aFFoY1RDM3BBQWhRNFlZUEVIb2lRdDFxeF84Nm8ifQ.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmZhbnR2LndvcmxkIiwiYXpwIjoicjI0YnNreHlhZnd3dWE2OGV0MndtdXFleW9hLmFwcHMuZmFudHYud29ybGQiLCJhdWQiOiJyMjRic2t4eWFmd3d1YTY4ZXQyd211cWV5b2EuYXBwcy5mYW50di53b3JsZCIsInN1YiI6IjYyOGRmNDU0YjA4MmE5NzAyOWNkYjNhZSIsIm5vbmNlIjoibG1scmxCakQ5ckFzdVFoZDdZUUFYTUlnQk1nIiwiaWF0IjoxNzIxNzM5NjAyLCJleHAiOjE3MjE4MjYwMDIsImp0aSI6Imx5eWZhenZtLWNmNDl3Zmd6YzkifQ.INczb6QnaOBuyLzXQWJA6Wt6caoLG-0rgm55GSBmux1SpH8bL8KSuUPArax1cAlPQjnAS7S4mn2PLBC584yTmfGpKesKJ1bYjqH4mnomt3ZTWnddofLMkB-ZxBl4TmOiTsWiFrObfNyQbHEOUKKsxoaTcyZHYPQ-F4MIEsQx_KJwYgBRD5lEY2vJbtbM_jzA1mxktFBIFWdF3JhTJ8hSRNlEMeVMWky3_boMUFCatf8sffIX62QTbZUMvNpMj519yN-IXpqR-hVWgwFNreIqKF_rQLNx2K2JQfBXEvDE8VoHjdbVT5MpRMMiPckrVp-fuQ77AiGapXOQcG_Y32Dbvw


## Reference Implementation

N/A. To be implemented by the Mysten Labs team. 

## Security Considerations


Security Measures for Certificate Signing Key

Q: What measures have you taken to secure the certificate signing key?

A: Usage of HSMs to securely store and manage our signing keys, implement strict access controls with multi-factor authentication, conduct regular security audits and monitoring, and follow a key rotation policy to periodically replace the keys.

Q: Can applications create client IDs against your issuer?

A: For now, this is for our use case only, we can open it to other applications or the Sui universe in the future if needed.


Q: What are the worst-case scenarios if the JWK endpoint is unavailable or the signing key is compromised?

A: JWK Endpoint Unavailability:
Impact: All zkLogin wallets will be locked out.
Plan: We have a redundant infrastructure and a rapid incident response team to restore service.


## Copyright

[CC0 1.0](../LICENSE.md).
