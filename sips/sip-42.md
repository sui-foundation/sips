| SIP-Number          | 42 |
| ---:                | :--- |
| Title               | Add Karrier One as a zkLogin OpenID provider |
| Description         | Add Karrier One as a whitelisted OpenID provider enabled for zkLogin on Sui. |
| Author              | Andrew Buchanan <abuchanan@karrier.one> |
| Editor              | Amogh Gupta <amogh@sui.io, @amogh-sui>  |
| Type                | Standard |
| Category            | Core |
| Created             | 2024-08-06 |
| Comments-URI        | https://sips.sui.io/comments-42 |
| Status              | Final |
| Requires            | NA |


## Abstract

Currently no providers enabled on Sui support login with a phone number. Phone number logins are a dominant credential option in many sectors and having such a provider for zkLogin is crucial for mass adoption of zkLogin. Here we propose to add Karrier One as an OpenID provider on Sui that enables login with a phone number. This will allow applications in the sui ecosystem to onboard users to Sui seamlessly using simply a phone number.

## Motivation

zkLogin does not support any providers using phone number-based logins.  Many popular applications use phone number based accounts and/or logins today and adding a zkLogin provider that supports phone numbers will enable builders in the sui ecosystem to also use phone number based logins for creating wallets and interacting with dApps.

## Specification

Karrier One is hosting an openid provider built upon https://github.com/openiddict/openiddict-core which implements https://openid.net/specs/openid-connect-core-1_0.html and supports the code & implicit flows. 


|             Item          | Endpoint  | Example Content | 
|-------------------------- |-----------|-----------------|
| Well known configuration  |    https://accounts.karrier.one/.well-known/openid-configuration       |                 |
| JWK endpoint              |    https://accounts.karrier.one/.well-known/jwks       |                 |
| Issuer                    |    https://accounts.karrier.one/   |                 |
| Authorization link        |    https://accounts.karrier.one/connect/authorize        |                 |
| Allowed Client IDs        |    karrier.one        |     | 

Additional Client IDs can be supported as the ecosystem grows.

#### JWK rotation details

Quarterly as standard behavoir.  Immediately if there is any suspicion of compromise, change in key personell or significant changes to the security infrastructure.  Old keys will be available for a period of 7 days when rotated out.

#### JWK endpoint availability

AWS Elastic Load Balancer with cross-zone load balancing and liveliness checks.  The service can be further scaled using Cloudfront (CDN), Auto Scaling groups, and Route 53 global load balancing as necessary.

#### Signing key storage details

Private S3 with Dual-layer server-side encryption with AWS Key Management Service keys (DSSE-KMS).  Key is additionally encrypted with AES 256 and the key stored in AWS Parameter Store as a Secure String encrypted with AWS KMS.  Key is active in the memory of the openid server but it not persisted to disk.

## Rationale

Dual-layer encryption with DSSE-KMS and AES 256 provides strong protection against unauthorized access. DSSE-KMS is designed to meet National Security Agency CNSSP 15 for FIPS compliance and Data-at-Rest Capability Package (DAR CP) Version 5.0 guidance for two layers of CNSA encryption.  Using AWS Parameter Store with a Secure String ensures that the AES key is protected by AWS's robust security mechanisms. 

Keeping the key in memory and not persisting it to disk further reduces the attack surface, making it harder for attackers to extract the key if they gain access to the server.

## Backwards Compatibility

ZkLogin wallets are domain separated by the OpenID issuer and its client ID. There is no backward compatibility issue with existing issuers. 

Once this SIP is finalized with the configurations defined above (issuer string, client ID etc), they will not change again. Otherwise, the wallet created based on this configuration will result in loss of funds. 


## Test Cases

eyJhbGciOiJSUzI1NiIsImtpZCI6IjYyNzA1RUEwMjMwMDAyNTFENUUwRDZCQkQyMkQzODFDMEVFQzlBOTgiLCJ4NXQiOiJZbkJlb0NNQUFsSFY0TmE3MGkwNEhBN3NtcGciLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmthcnJpZXIub25lLyIsImV4cCI6MTcyMzc4Nzc4MSwiaWF0IjoxNzIzNzg2NTgxLCJhdWQiOiJkYXNoYm9hcmQtZGV2Iiwic3ViIjoiZDExZjAwNmUtNzczOS00NTEwLWE5NTgtMzYwM2VhZDNmNzQwIiwiZW1haWwiOiJkZW1vLW9wZXJhdG9yQGthcnJpZXIub25lIiwibmFtZSI6ImRlbW8tb3BlcmF0b3JAa2Fycmllci5vbmUiLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJkZW1vLW9wZXJhdG9yQGthcnJpZXIub25lIiwiZmFtaWx5X25hbWUiOiJPcGVyYXRvciIsImdpdmVuX25hbWUiOiJEZW1vIFJhZGlvIiwiaWRlbnRpZmllciI6ImVtYWlsIiwib2lfYXVfaWQiOiIyMWJmMDZiMi0zNDYwLTRjMzMtYWE3Yi1hODBhYzJmYjdhNjkiLCJhenAiOiJkYXNoYm9hcmQtZGV2Iiwibm9uY2UiOiJoVFBwZ0Y3WEFLYlczN3JFVVM2cEVWWnFtb0kiLCJvaV90a25faWQiOiI3YTZlNDMyZC03NzgwLTQ1YTMtODdlNS1jZTEwZDI2YmU5Y2EifQ.ezpSDhImPSjojX6w_RKlHX55k6Sh9CJS9oHCtc1ddXtH42T1BN0Zp08DrqlCT0_vpsk6H_m6My7F4JDBnDE2r0qquRs_7eRyE7q5bhEDJRGgiRQI3dq-FOBHpVPxGB-U5gZwvDyJxW2tl-rYJynxsdZBwg4MpVHG4nQy_Vi8f0QYpvYBst7ddzPO8SE2AR-QQ2TnUt6dDvVYSJ9FtV83s-__0EEJN0zg-C6EtdTtrPkMo2stK-Zc9ciTuK1QSx6qBo9IwCloBmVz66m6tSDVCHzftappj5LrSCh2x5-fc-RLZm2l-OksKcxPHIx3vGbnz7o1QyqoW4y2UCN6e6hPlg

{
  "alg": "RS256",
  "kid": "62705EA023000251D5E0D6BBD22D381C0EEC9A98",
  "x5t": "YnBeoCMAAlHV4Na70i04HA7smpg",
  "typ": "JWT"
}
{
  "iss": "https://accounts.karrier.one/",
  "exp": 1723787781,
  "iat": 1723786581,
  "aud": "dashboard-dev",
  "sub": "d11f006e-7739-4510-a958-3603ead3f740",
  "email": "demo-operator@karrier.one",
  "name": "demo-operator@karrier.one",
  "preferred_username": "demo-operator@karrier.one",
  "family_name": "Operator",
  "given_name": "Demo Radio",
  "identifier": "email",
  "oi_au_id": "21bf06b2-3460-4c33-aa7b-a80ac2fb7a69",
  "azp": "dashboard-dev",
  "nonce": "hTPpgF7XAKbW37rEUS6pEVZqmoI",
  "oi_tkn_id": "7a6e432d-7780-45a3-87e5-ce10d26be9ca"
}

Basic Third-Party Login
https://www.loom.com/share/1c4aafe9d3cf4b1d8b37f87bb1619711?sid=2174c44c-dc34-4d4d-8fee-5b2487e6b9ba


## Reference Implementation

N/A. To be implemented by the Mysten Labs team. 

## Security Considerations

Client ID's are not shared between applications.  The same user will be issued a new client ID for each application.  This guarantees separate applications will have unique zk wallet addresses even if the same salt value was chosen.

The Certificate signing key is in a private s3 bucket with DSSE-KMS encryption and an additional layer of AES 256 is applied to the signing keys.  Using AWS IAM policies the bucket is restricted to the OpenId vm's.  

Worst case scenarios:
JWK endpoint is unavailable.  All zkLogin wallets are locked out until the JWK endpoint is restored.  Mitigation is to deploy a high availability infrastructure.

Signing key is compromised.  Wallets could have funds drained.  Mitigations include encrypting the signing keys, limiting access to the signing keys to required processes and staff.  Logging access.  At the user/application level, require users with significant assets (eg more $1000) to use a standard/private wallet.

