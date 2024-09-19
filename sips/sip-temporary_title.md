Arden OIDC SIP

|   SIP-Number | N/A |
| -----------: | :--------------------------------------------------- |
|        Title | Add Arden as a zkLogin OpenID provider |
|  Description | Add Arden as a whitelisted OpenID provider enabled for zkLogin on Sui. |
|       Author |  Arden  |
|       Editor | N/A |
|         Type | Standard |
|     Category | Core |
|      Created | 2024-09-05 |
| Comments-URI | N/A |
|       Status | N/A |
|     Requires | N/A |


## Abstract
Currently, zkLogin does not support login with just an email address. This is arguably the most common form of login and necessary for Arden’s Quest Commerce loyalty platform. Furthermore, many customers don’t want to connect a social account (or for our demographic, may not have a social account) to sign up / login.


## Motivation
In order to successfully onboard tens of thousands of users to the Sui blockchain with the lowest amount of friction, Arden’s loyalty platform requires that customers are able to sign up / login by solely using their email.


## Specification

Arden OIDC is fully compatible with the current [OpenID specification](https://openid.net/specs/openid-connect-core-1_0.html) with the following configurations:




EXAMPLE 
|             Item          | Endpoint  | Example Content | 
|-------------------------- |-----------|-----------------|
| Well known configuration  |    https://api.arden.cc/auth/.well-known/openid-configuration       |                 |
| JWK endpoint              |    https://api.arden.cc/auth/jwks       |                 |
| Issuer                    |    https://oidc.arden.cc    |                 |
| Authorization link          |   https://api.arden.cc/auth/authorize        |                 |
| Allowed Client IDs |    |   02d841ba-e78e-4762-81c1-f8bd913d6f82   | 

## JWK rotation details

JWKs are rotated every 90 days 

## JWK endpoint availability

We don’t provide a status page to track liveness 

## Signing key storage details

Signing keys are stored and managed by Google Cloud Platform’s Secret Manager. 

## Rationale

Discuss the whys for rotation schedule and signing key storage options, any other alternatives considered and how you come to such a decision. 

Security Best Practices: A 90-day rotation aligns with industry standards for cryptographic key management, providing a balance between security and operational overhead.
Risk Mitigation: Regular rotation limits the potential impact of an undetected key compromise, reducing the window of vulnerability.
Operational Feasibility: Quarterly rotation allows for manageable oversight and verification processes without overburdening our operations team.

We chose Google Cloud Secret Manager for storing our signing keys due to several advantages:
Built-in Encryption: It provides automatic encryption at rest and in transit, meeting high security standards.
Access Control: Granular IAM policies allow us to strictly limit and audit access to these critical secrets.
Versioning: Secret Manager's versioning capabilities complement our rotation strategy, maintaining a clear history of key changes.
Integration: Seamless integration with other Google Cloud services, including our Cloud Functions for automated rotation, streamlines our operations.


## Backwards Compatibility

ZkLogin wallets are domain separated by the OpenID issuer and its client ID. There is no backward compatibility issue with existing issuers. 

Once this SIP is finalized with the configurations defined above (issuer string, client ID etc), they will not change again. Otherwise, the wallet created based on this configuration will result in loss of funds. 









## Test Cases

Provide an example JWT token and parsed JWT token payload (using jwt.io) with nonce hTPpgF7XAKbW37rEUS6pEVZqmoI

### JWT
    eyJhbGciOiJSUzI1NiIsImtpZCI6InJzYS0yMDQ4LTE3MjU1NTIwNjgiLCJ0eXAiOiJKV1QifQ.eyJzdWIiOiJkZXZAYXJkZW4uY2MiLCJlbWFpbCI6ImRldkBhcmRlbi5jYyIsImF1ZCI6IjAyZDg0MWJhLWU3OGUtNDc2Mi04MWMxLWY4YmQ5MTNkNmY4MiIsInNjb3BlIjoib3BlbmlkIiwibm9uY2UiOiJoVFBwZ0Y3WEFLYlczN3JFVVM2cEVWWnFtb0kiLCJleHAiOjE3MjU1NTYwNDgsImlhdCI6MTcyNTU1MjQ0OCwiaXNzIjoiaHR0cHM6Ly9vaWRjLmFyZGVuLmNjIn0.HKf5ejMp0nxBSrAS2losqjSPHju-MbB9PdAzG81fdgE6mGT3RDpkQkPjdx0RgSOfdKt3cEXV82Y-ZwslzKn7R4pMsuX3G06AKDSdJdRjGz4Dx0nryYzbPQCCasS_u5X9KkVSS0qxd7jKX2q5krfnxQZtGj6HVNbysF43xSNXXNLHrAm5G_PG4aY9C-v-engGxIu6Y7OJSMZY4bDW5E43i1lBxES_3uozYEJ8JieMSApTsgywDql2dGM_4H9mJE_Ijwa4UlE0xHq9MLwbs0rRuLt_p5fFplOfWeYbm6n3hR0kKYI8YkOs1AK8iFzuhbmopByID-Dxslg1oyEm9UV8bg

### Parsed JWT

#### Header

    {
      "alg": "RS256",
      "kid": "rsa-2048-1725552068",
      "typ": "JWT"
    }

#### Payload Data

    {
      "sub": "dev@arden.cc",
      "email": "dev@arden.cc",
      "aud": "02d841ba-e78e-4762-81c1-f8bd913d6f82",
      "scope": "openid",
      "nonce": "hTPpgF7XAKbW37rEUS6pEVZqmoI",
      "exp": 1725556048,
      "iat": 1725552448,
      "iss": "https://oidc.arden.cc"
    }


[Video of complete login flow](https://youtu.be/QMF7C_2by3U)



## Reference Implementation

N/A. To be implemented by the Mysten Labs team. 

## Security Considerations

Discuss what measures you have taken to secure the certificate signing key. Discuss whether applications can create client ID against your issuer. 

Our certificate signing key is secured using Google Cloud Secret Manager, providing enterprise-grade encryption at rest and in transit. Access to this key is strictly controlled through Google Cloud's IAM policies, ensuring that only authorized services can retrieve it. The key is never exposed in our application code, being retrieved securely and used only when necessary for JWT signing operations.
We've implemented an automated key rotation mechanism using Google Cloud Functions, scheduled to execute every 90 days. This regular rotation significantly reduces the risk window associated with potential key compromises.

Discuss worst case scenarios. If the JWK endpoint is unavailable, all zkLogin wallets associated with the provider will be locked out of their wallet since JWT cannot be generated. If the signing key is compromised, all wallets associated with this provider will result in loss of funds since anyone can forfeit the JWT and ZK proof as a result. 

Currently, our system does not support dynamic creation of client IDs against our issuer. Client IDs are created internally upon request and carefully managed to maintain strict control over authorized applications. This approach enhances security by limiting the attack surface and ensuring that only vetted applications can interact with our OIDC provider.

In the event of a signing key compromise, we recognize the potential for unauthorized access to associated wallets. Our 90-day key rotation policy significantly reduces the window of vulnerability. We're also implementing comprehensive monitoring and alerting systems to detect unusual JWT issuance patterns, allowing for quick response to potential breaches.

## Copyright

[CC0 1.0](../LICENSE.md).
