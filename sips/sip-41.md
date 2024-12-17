
|   SIP-Number | 41 |
|         ---: | :--- |
|        Title | Add Credenza OpenID |
|  Description | OpenID provider enabled for zkLogin on Sui. |
|       Author | Credenza Inc. |
|       Editor | Will Riches \<will@sui.io, @wriches\> |
|         Type | Standard |
|     Category | Core |
|      Created | 2024-08-22 |
| Comments-URI | https://sips.sui.io/comments-41 |
|       Status | Fast Track |
|     Requires | |


## Abstract

Credenza provides Passport as a simple authentication + wallets system to embed into existing accounts with access to domain-specific contracts to manage customer data, loyalty programs, digital rights management, and other critical use cases for sports & entertainment customers.

## Motivation

Credenza’s traction and ability to offer an extensible solution for sports teams allow for unique access to Credenza’s managed contracts and SaaS platform to open the door to common use cases in the sports & entertainment space and will allow Credenza to seamlessly migrate customers from Polygon.

## Specification

Credenza’s system is compatible with the current OAuth standards.

### OIDC configuration

https://accounts.credenza3.com/openid-configuration

    {
    "issuer": "string",
    "authorization_endpoint": "string",
    "token_endpoint": "string",
    "userinfo_endpoint": "string",
    "revocation_endpoint": "string",
    "jwks_uri": "string",
    "response_types_supported": [],
    "subject_types_supported": [],
    "id_token_signing_alg_values_supported": [],
    "scopes_supported": [],
    "token_endpoint_auth_methods_supported": [],
    "claims_supported": [],
    "code_challenge_methods_supported": [],
    "grant_types_supported": []
    }

### JWK endpoint

https://accounts.credenza3.com/jwks

    {
    "keys": [
    {
    "kty": "string",
    "kid": "string",
    "use": "string",
    "alg": "string",
    "e": "string",
    "n": "string"
    },
    ]
    }

Issuer
- `https://accounts.credenza3.com`

Authorization link
- `https://accounts.credenza3.com/oauth2/authorize`
- `https://accounts.credenza3.com/oauth2/authorize?client_id=65954ec5d03dba0198ac343a&response_type=token&scope=openid+profile+email+phone+blockchain.sui+blockchain.sui.write&state=state&redirect_uri=https%3A%2F%2Fwww.example.com%2Fcallback&nonce=hTPpgF7XAKbW37rEUS6pEVZqmoI`

Allowed Client IDs
- `*`
- `65954ec5d03dba0198ac343a`


## JWK rotation details

Every 180 days.

## JWK endpoint availability

https://status.credenza3.com When the app goes down, Credenza get a slack notification so we can fix it ASAP
JWK is served through the accounts app.

## Signing key storage details

Is stored in the DB additionally encrypted.

## Rationale

We do not have many users currently, so we decide we are good with a standard periodic rotation, with the dual key strategy. 180d overlap.

## Backwards Compatibility

zkLogin wallets are domain separated by the OpenID issuer and its client ID. There is no backward compatibility issue with existing issuers. 

Once this SIP is finalized with the configurations defined above (issuer string, client ID etc), they will not change again. Otherwise, the wallet created based on this configuration will result in loss of funds. 

## Test Cases

```
Nonce: hTPpgF7XAKbW37rEUS6pEVZqmoI
eyJ0eXAiOiJqd3QiLCJhbGciOiJSUzI1NiIsImtpZCI6IkpHNm9aa0lCcVFka3BuQ25ENDc5ekZYZ01BNV9JN2ktYUhBVjBNUnd2RHMifQ.eyJpYXQiOjE3MjQ0MTc5ODQsImV4cCI6MTc4NDQxNzkyNCwiYXVkIjoiNjU5NTRlYzVkMDNkYmEwMTk4YWMzNDNhIiwiaXNzIjoiaHR0cHM6Ly9hY2NvdW50cy5jcmVkZW56YTMuY29tIiwic3ViIjoiNjViMGU5ZjViOWZmOWI1MjI1ZGMwYWJiIiwic2NvcGUiOiJvcGVuaWQgcHJvZmlsZSBlbWFpbCBwaG9uZSBibG9ja2NoYWluLmV2bSBibG9ja2NoYWluLmV2bS53cml0ZSBibG9ja2NoYWluLnN1aSBibG9ja2NoYWluLnN1aS53cml0ZSIsInRva2VuX3R5cGUiOiJCZWFyZXIiLCJ0b2tlbl91c2UiOiJhY2Nlc3MiLCJub25jZSI6ImhUUHBnRjdYQUtiVzM3ckVVUzZwRVZacW1vSSJ9.CfnlaM77g2_stGQmCRTOPwNqK0aaDEWux_b36lwCt1Mq8G99GBazJ18WqK9472EKF89CMGHOoVpaYN9WNXOqUNEmvNY3mtW0UTH8MiSHRO5Hc1qGJo2Bun8Xjm84EMyUrm9-eh0yK33rQ8laKaXdzW-epWM4095U4gpH9n3xi749hh_ua_G-O16u-dW6-T2lubBibya_FTFPbLsqgGDJs7hIXk3AJGzUxDvN0ig5g89whyauuPZuvix3hSGuFxO-Gwk0eCQFSuF6YMSf7oOnMf0d8FYvHLsJD23QBsOlNBRY7S8ZwihbJztk7ipaTKqvB1R_eeF-q1vNkppo34rmkw
```

## Reference Implementation

N/A. To be implemented by the Mysten Labs team. 

## Security Considerations

The certificate signing key is stored in the DB aes-256-cbc encrypted. 
OAUTH2/OIDC users CAN create no more then 2 clients (Public + Confidential) at https://developers.credenza3.com

If the JWK endpoint is unavailable, all zkLogin wallets associated with the provider will be locked out of their wallet since JWT cannot be generated. 
If the signing key is compromised, all wallets associated with this provider will result in loss of funds since anyone can forfeit the JWT and ZK proof as a result. 

## Copyright

Copyright Credenza Inc., 2024