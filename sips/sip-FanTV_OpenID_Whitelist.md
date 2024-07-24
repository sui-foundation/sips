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

|             Item          | Endpoint  | Example Content | 
|-------------------------- |-----------|-----------------|
| Well known configuration  |https://accounts.fantv.world/.well-known/openid-configuration | `{             "issuer": "https://accounts.fantv.world",             "authorization_endpoint": "https://fantv-apis.fantiger.com/v1/oauth2/auth",             "token_endpoint": "https://fantv-apis.fantiger.com/v1/oauth2/token",             "jwks_uri": "https://fantv-apis.fantiger.com/v1/web3/jwks.json",             "response_types_supported": [                 "authorization_code",                 "id_token"             ],             "subject_types_supported": [                 "public"             ],             "id_token_signing_alg_values_supported": [                 "RS256"             ],             "scopes_supported": [                 "openid"             ],             "token_endpoint_auth_methods_supported": [                 "client_secret_post",                 "client_secret_basic"             ],             "claims_supported": [                 "aud",                 "exp",                 "iat",                 "iss",                 "sub"             ],             "code_challenge_methods_supported": [                 "plain",                 "S256"             ]         }` |
| JWK endpoint              |https://fantv-apis.fantiger.com/v1/web3/jwks.json | `{"keys":[{"kty":"RSA","kid":"O5ryxF-zMCLmS6hQhcTC3pAAhQ4YYPEHoiQt1qx_86o","use":"sig","alg":"RS256","e":"AQAB","n":"mBi1td_GT0MubU5Lfeg4P4XsMUzpzcxuI9Yb1xDOpWFekEZF0TwTLJ6v4a28hiAU_ateCxlFQSkHrhbpdFkEWuDQnPUAnlAr5I7-W8ccKkWuuPwZz0wHcgFSxH5fstFaGuOACewBSmP3BlScQqRYhrj1QB_7j1_G7g17Q-QIBGrvp8gtb2K-saumUlF67ySZrSM_FV1_XalI0Z31oXKMECUfnbje-fLiIvSuXKK-sfO-MSrEEkB8dbzP6ez-xYGYIFisyiqeGlCeO4-ZDkvDrBnDGLxpgLcsWbgcUUvnmyrSQjTxqub17GkuPPwXpof0b8OHhPAC12TfUTRRP1CUfQ"}]}`|
| Issuer                    |https://accounts.fantv.world |                 |
| Authorization link        |https://fantv-apis.fantiger.com/v1/oauth2/auth?clientId=r24bskxyafwwua68et2wmuqeyoa.apps.fantv.world&redirectUri=https://fantv-apis.fantiger.com/v1/oauth2/redirect&responseType=authorization_code&scope=openid&userId=6443505c5de5935daf15635c&sessionId=293572390582343345ndbsbfhergkj32438|                 |
| Allowed Client IDs        |r24bskxyafwwua68et2wmuqeyoa.apps.fantv.world|                 | 

## JWK rotation details

The JWK rotation happens on monthly basis and it is configurable based upon security measures and operational overhead in future. 

## JWK endpoint availability

Current endpoint is always available. It is deployed on highly scalable servers and is running on multiple geo-location based servers and we have implemented alerting systems for continuous monitoring.

## Signing key storage details

We are using AWS HSM model to store the private key.

## Claims 

Is there any other custom claims supported by the payload in addition to `sub`, `aud`, `nonce`? If so, what are they and is there a maximum length and type check enforced? (i.e. it is not possible to pass in a JSON format with nested claims inside). 

`sub` field is unique, since the user ID is derived from the object ID of a single MongoDB instance to ensure uniqueness. `aud` and `nonce` both fields are supported, and only string is allowed. `nonce` doesn't have a fixed length and aud is an URL identifier. 

## Rationale

JWT signing key rotation is an important security practice. Here are the key reasons why it's mandatory:

Mitigation of Key Compromise Risks, Compliance with Security Policies and Standards, Expiration and Revocation Management

AWS HSM module is the best industry solution for storing keys securely and for signing JWT payloads securely. Rotation is to maintain safety and the frequency is subjective of operational overheads.

## Backwards Compatibility

ZkLogin wallets are domain separated by the OpenID issuer and its client ID. There is no backward compatibility issue with existing issuers. 

Once the SIP is finalized with the configurations defined above (issuer string, client ID etc), they will not change again. Otherwise, the wallet created based on this configuration will result in lost of fund. 

## Test Cases

eyJ0eXAiOiJqd3QiLCJhbGciOiJSUzI1NiIsImtpZCI6Ik81cnl4Ri16TUNMbVM2aFFoY1RDM3BBQWhRNFlZUEVIb2lRdDFxeF84Nm8ifQ.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmZhbnR2LndvcmxkIiwiYXpwIjoicjI0YnNreHlhZnd3dWE2OGV0MndtdXFleW9hLmFwcHMuZmFudHYud29ybGQiLCJhdWQiOiJyMjRic2t4eWFmd3d1YTY4ZXQyd211cWV5b2EuYXBwcy5mYW50di53b3JsZCIsInN1YiI6IjYyOGRmNDU0YjA4MmE5NzAyOWNkYjNhZSIsIm5vbmNlIjoibG1scmxCakQ5ckFzdVFoZDdZUUFYTUlnQk1nIiwiaWF0IjoxNzIxNzM5NjAyLCJleHAiOjE3MjE4MjYwMDIsImp0aSI6Imx5eWZhenZtLWNmNDl3Zmd6YzkifQ.INczb6QnaOBuyLzXQWJA6Wt6caoLG-0rgm55GSBmux1SpH8bL8KSuUPArax1cAlPQjnAS7S4mn2PLBC584yTmfGpKesKJ1bYjqH4mnomt3ZTWnddofLMkB-ZxBl4TmOiTsWiFrObfNyQbHEOUKKsxoaTcyZHYPQ-F4MIEsQx_KJwYgBRD5lEY2vJbtbM_jzA1mxktFBIFWdF3JhTJ8hSRNlEMeVMWky3_boMUFCatf8sffIX62QTbZUMvNpMj519yN-IXpqR-hVWgwFNreIqKF_rQLNx2K2JQfBXEvDE8VoHjdbVT5MpRMMiPckrVp-fuQ77AiGapXOQcG_Y32Dbvw

TODO: Provide a long-live video clip of a complete login flow for testing and/or screenshots. 

## Reference Implementation

N/A. To be implemented by the Mysten Labs team. 

## Security Considerations

Usage of HSMs to securely store and manage our signing keys, implement strict access controls with multi-factor authentication, conduct regular security audits and monitoring, and follow a key rotation policy to periodically replace the keys.

Application cannot currently create client IDs against your issuer. The current client ID is for our use case only, we can open it to other applications or the Sui universe in the future if needed.

If the JWK endpoint is unavailable, all zkLogin wallets associated with the provider will be locked out of their wallet since JWT cannot be generated. If the signing key is compromised, all wallets associated with this provider will result in loss of funds since anyone can forfeit the JWT and ZK proof as a result. 

 If the JWK endpoint is unavailable, all zkLogin wallets associated with the provider will be locked out of their wallet since JWT cannot be generated. We have a redundant infrastructure and a rapid incident response team to restore service.

## Copyright

[CC0 1.0](../LICENSE.md).
