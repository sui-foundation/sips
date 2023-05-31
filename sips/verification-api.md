|   SIP-Number | <Leave this blank; it will be assigned by a SIP Editor>                   |
|-------------:|:--------------------------------------------------------------------------|
|        Title | Code Verification API                                                     |
|  Description | a standard protocol for the verification of SUI Move smart contract code. |
|       Author | kairoski03                                                                |
|       Editor |                                                                           |
|         Type | Informational                                                             |
|     Category |                                                                           |
|      Created | 2023-05-26                                                                |
| Comments-URI |                                                                           |
|       Status |                                                                           |
|     Requires |                                                                           |

## Abstract
This proposal suggests the specification of a verification API that verify source code of an on-chain package.

## Motivation
There is currently no way to view the actual source code of an on-chain package if only the package ID is given. Even if the package source code is public, you should download the source code and verify it using the CLI. However, users usually query the package in the SUI explorer. If someone uploads verify the source code once and anyone can view the verified source code in the SUI explorer, it will improve usability and make the network more transparent. The API suggested in this proposal will enable this feature.

## Specification
### 1. Upload Source Code and Request Verification
  - #### **Headers**
    - "Content-Type": "multipart/form-data"
  
  - #### **Request Body**
    For uploading of the package source code, you should send a **`POST`** request to the API endpoint. The required parameters are below.
    - **`network`**: The name of the network where the smart contract is deployed. (ex, mainnet)
    - **`packageId`**: The package ID where the smart contract is deployed.
    - **`suiCliVersion`**: The version of SUI CLI.
    - **`srcCodeZipFile`** : The package source code compressed zip file.(In NodeJS, File type)
    
  - #### **Response**
    The API returns the status of verification. Please note that it does not response the result of verification but the result indicating whether the request has been properly received or not.
    - **`network`**: The name of the network where the smart contract is deployed. (ex, mainnet)
    - **`packageId`**: The package ID where the smart contract is deployed.
    - **`status`** 
      - ACCEPTED: The request has been queued successfully.
      - ALREADY_VERIFIED: The package is already verified.
      - INTERNAL_ERROR: API Server has internal error.
      - INVALID_FILE: The file is not invalid. (ex. Move.toml non included)

### 2. Get Verified Source Code
  - #### **Request**
    To obtain the verified package source code, you should send a **`GET`** request to the API endpoint. The required parameters are below.
    - **`network`**: The name of the network where the smart contract is deployed. (ex, mainnet)
    - **`packageId`**: The package ID where the smart contract is deployed.

  - #### **Response**
    The API returns the verification result including below fields:
    - **`network`**: The name of the network where the smart contract is deployed. (ex, mainnet)
    - **`packageId`**: The package ID where the smart contract is deployed.
    - **`suiCliVersion`**: The version of SUI CLI.
    - **`isVerified`**: Whether it is verified.
    - **`srcUrl`**: If verified, the download url for a zip compressed file of source code or null.

## Rationale
  1. API does not return source code string but source download url because of API response time.
  2. Verification server does not use SUI CLI verify-source command. Instead, it builds with SUI CLI version which is included in the API request. It compares on-chain bytecode and build artifacts. The reason is that this way covers the case that the package address is 0x or published-at is none in Move.toml.
  3. It requires source code storage like AWS S3 because SUI does not store source code in on-chain.
  4. It requires API servers which collect verification requests and query if the package is verified. 
  5. It requires verification servers which verify source code.
  6. It requires database which saves verification requests and status. 

## Backwards Compatibility

There are no issues with backwards compatability.

## Test Cases

## Reference Implementation

## Security Considerations
None

## Copyright
DSRV labs.
