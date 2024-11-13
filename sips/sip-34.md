|   SIP-Number | 34 |
| -----------: | :--------------------------------------------------- |
|        Title | Add FanTV as a zkLogin OpenID provider |
|  Description | Add FanTV as a whitelisted OpenID provider for zkLogin on Sui to enable logging in with phone numbers to create Sui wallets. |
|       Author | Jaswant Kumar <@jaswant25, jaswant.kumar@fantv.in>, Joy Wang <joy@mystenlabs.com, @joyqvq> |
|       Editor | Will Riches <will@sui.io, @wriches> |
|         Type | Standard |
|     Category | Core |
|      Created | 2024-06-07 |
| Comments-URI | https://sips.sui.io/comments-34 |
|       Status | Final |
|     Requires | |

## Abstract

Currently no providers enabled on Sui support logging in with a phone number. Phone number login is a dominant credential option in many sectors and having such a provider for zkLogin is crucial for mass adoption of zkLogin. Here we propose to add FanTV as a OpenID provider on Sui that enables login with phone number. This will onboard FanTV users to Sui seamlessly and also allows users for other Sui applications with simply a phone number.

## Motivation

Phone number login is a dominant credential option in many markets. Having such a provider for zkLogin is crucial for mass adoption for Sui. This allows anyone with a phone number to create a wallet on Sui and interact with dApps. 

## Specification

FanTV is fully compatible with the current [OpenID specification](https://openid.net/specs/openid-connect-core-1_0.html) with the following configurations:

|             Item          | Endpoint  | Example Content | 
|-------------------------- |-----------|-----------------|
| Well known configuration  |https://accounts.fantv.world/.well-known/openid-configuration | `{             "issuer": "https://accounts.fantv.world",             "authorization_endpoint": "https://fantv-apis.fantiger.com/v1/oauth2/auth",             "token_endpoint": "https://fantv-apis.fantiger.com/v1/oauth2/token",             "jwks_uri": "https://fantv-apis.fantiger.com/v1/web3/jwks.json",             "response_types_supported": [                 "authorization_code",                 "id_token"             ],             "subject_types_supported": [                 "public"             ],             "id_token_signing_alg_values_supported": [                 "RS256"             ],             "scopes_supported": [                 "openid"             ],             "token_endpoint_auth_methods_supported": [                 "client_secret_post",                 "client_secret_basic"             ],             "claims_supported": [                 "aud",                 "exp",                 "iat",                 "iss",                 "sub"             ],             "code_challenge_methods_supported": [                 "plain",                 "S256"             ]         }` |
| JWK endpoint              |https://fantv-apis.fantiger.com/v1/web3/jwks.json | `{"keys":[{"kty":"RSA","kid":"O5ryxF-zMCLmS6hQhcTC3pAAhQ4YYPEHoiQt1qx_86o","use":"sig","alg":"RS256","e":"AQAB","n":"mBi1td_GT0MubU5Lfeg4P4XsMUzpzcxuI9Yb1xDOpWFekEZF0TwTLJ6v4a28hiAU_ateCxlFQSkHrhbpdFkEWuDQnPUAnlAr5I7-W8ccKkWuuPwZz0wHcgFSxH5fstFaGuOACewBSmP3BlScQqRYhrj1QB_7j1_G7g17Q-QIBGrvp8gtb2K-saumUlF67ySZrSM_FV1_XalI0Z31oXKMECUfnbje-fLiIvSuXKK-sfO-MSrEEkB8dbzP6ez-xYGYIFisyiqeGlCeO4-ZDkvDrBnDGLxpgLcsWbgcUUvnmyrSQjTxqub17GkuPPwXpof0b8OHhPAC12TfUTRRP1CUfQ"}]}`|
| Issuer                    |https://accounts.fantv.world |                 |
| Authorization link        |https://fantv-apis.fantiger.com/v1/oauth2/auth?clientId=r24bskxyafwwua68et2wmuqeyoa.apps.fantv.world&redirectUri=https://fantv-apis.fantiger.com/v1/oauth2/redirect&responseType=authorization_code&scope=openid&userId=6443505c5de5935daf15635c&nonce=f4wytgbi34jgkefhjwer112121|                 |
| Token end point | https://fantv-apis.fantiger.com/v1/oauth2/token | Post params: `{"clientId":"r24bskxyafwwua68et2wmuqeyoa.apps.fantv.world","clientSecret":"secret123456","grant_type":"authorization_code","redirect_uri":"https://fantv-apis.fantiger.com/v1/oauth2/redirect","authCode":"1758a96d2f7ce2bb8d8326b21cff1a8f8bf1b61a39ade2e9923e2f8a75703fa1"}`
| Allowed Client IDs        |r24bskxyafwwua68et2wmuqeyoa.apps.fantv.world|                 | 

## JWK rotation details

The JWK rotation happens on monthly basis and it is configurable based upon security measures and operational overhead in future. 

## JWK endpoint availability

Current endpoint is always available. It is deployed on highly scalable servers and is running on multiple geo-location based servers and we have implemented alerting systems for continuous monitoring.

## Signing key storage details

We are using AWS HSM model to store the private key.

## Claims 

Are there any other custom claims supported by the payload in addition to `sub`, `aud`, `nonce`? If so, what are they and is there a maximum length and type check enforced? (i.e. it is not possible to pass in a JSON format with nested claims inside). 

`sub` field is unique, since the user ID is derived from the object ID of a single MongoDB instance to ensure uniqueness. `aud` and `nonce` both fields are supported, and only string is allowed. `nonce` doesn't have a fixed length and aud is an URL identifier. 

## Rationale

JWT signing key rotation is an important security practice. Here are the key reasons why it's mandatory:

Mitigation of Key Compromise Risks, Compliance with Security Policies and Standards, Expiration and Revocation Management

AWS HSM module is the best industry solution for storing keys securely and for signing JWT payloads securely. Rotation is to maintain safety and the frequency is subjective of operational overheads.

## Backwards Compatibility

zkLogin wallets are domain separated by the OpenID issuer and its client ID. There are no backward compatibility issues with existing issuers. 

Once the SIP is finalized with the configurations defined above (issuer string, client ID etc), they will not change again. Otherwise, the wallet created based on this configuration will result in the loss of funds. 

## Test Cases

eyJ0eXAiOiJqd3QiLCJhbGciOiJSUzI1NiIsImtpZCI6Ik81cnl4Ri16TUNMbVM2aFFoY1RDM3BBQWhRNFlZUEVIb2lRdDFxeF84Nm8ifQ.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmZhbnR2LndvcmxkIiwiYXpwIjoicjI0YnNreHlhZnd3dWE2OGV0MndtdXFleW9hLmFwcHMuZmFudHYud29ybGQiLCJhdWQiOiJyMjRic2t4eWFmd3d1YTY4ZXQyd211cWV5b2EuYXBwcy5mYW50di53b3JsZCIsInN1YiI6IjY0NDM1MDVjNWRlNTkzNWRhZjE1NjM1YyIsIm5vbmNlIjoiZjR3eXRnYmkzNGpna2VmaGp3ZXIxMTIxMjEiLCJpYXQiOjE3MjMxOTI5MDAsImV4cCI6MTcyMzE5NjUwMCwianRpIjoibHptZ2s3dGgtY2VpdDRvNW1kbyJ9.DbC5_2tRWhEcaj8GaWEu7aRe9iH3sKHRVwPPSDSfpU83lRcqCkbPh9Glzcv-lAie0xenhU_jeFP9qeBZ0wKTnaJonhbrzYDDrGwjBEOqPqh5XE5BGM6qBqLSZJmmvJ7KWqwb7IHhXOGCAJFwdpMoZ7mWxIw9xqcZbDhi8w4dDMVr3lMsDTIhy8x_QnzDqf1gfx9ZgDlWY3CelKK67J2mtiW0IfaEPGq5ITUQxE8sMfDfgqmsdGiIJFHG9xdtVjJWMI--oBmfwD97byyu3Ss_YyBxjizzP6cAE2G3tb7ERpPlRX84qdd0uQUOCalQxBfaIiAnea6GEzAHIJWFrd1AtA

## Reference Implementation

N/A. To be implemented by the Mysten Labs team.

## Security Considerations

Usage of HSMs to securely store and manage our signing keys, implement strict access controls with multi-factor authentication, conduct regular security audits and monitoring, and follow a key rotation policy to periodically replace the keys.

Application cannot currently create client IDs against your issuer. The current client ID is for our use case only, we can open it to other applications or the Sui universe in the future if needed.

If the JWK endpoint is unavailable, all zkLogin wallets associated with the provider will be locked out of their wallet since JWT cannot be generated. If the signing key is compromised, all wallets associated with this provider will result in loss of funds since anyone can forfeit the JWT and ZK proof as a result. 

 If the JWK endpoint is unavailable, all zkLogin wallets associated with the provider will be locked out of their wallet since JWT cannot be generated. We have a redundant infrastructure and a rapid incident response team to restore service.

## Copyright

[CC0 1.0](../LICENSE.md).
