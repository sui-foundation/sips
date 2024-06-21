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
| Well known configuration  |           |                 |
| JWK endpoint              |           |                 |
| Issuer                    |           |                 |
| Authorization link          |           |                 |

## JWK rotation details

(todo) include discussion on JWK rotation frequency and policy here. 

## JWK endpoint availability

(todo) include discussion on what measures had been taken to ensure the JWK availability, i.e. status page to track liveness. 

## Signing key storage details

(todo) include the infra that you had implemented or used to ensure the certificate signing key is well managed and secure. 

## Rationale

(todo) discuss the whys for rotation schedule and signing key storage options, any other alternatives considered and how you come to such a decision . 

## Backwards Compatibility

ZkLogin wallets are domain separated by the OpenID issuer and its client ID. There is no backward compatibility issue with existing issuers. 

## Test Cases

(todo) provide an example JWT token and parsed JWT token payload (using jwt.io)

(todo) provide a long-live video clip of a complete log in with phone number flow for testing and/or screenshots. 

## Reference Implementation

N/A. To be implemented by the Mysten Labs team. 

## Security Considerations

(todo) discuss what measures you have taken to secure the certificate signing key. discuss whether applications can create client ID against your issuer. 

## Copyright

[CC0 1.0](../LICENSE.md).
