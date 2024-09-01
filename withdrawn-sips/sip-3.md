|   SIP-Number | 3                                                                         |
|-------------:|:--------------------------------------------------------------------------|
|        Title | Code Verification API                                                     |
|  Description | A standard protocol for the verification of SUI Move smart contract code. |
|       Author | kairoski03                                                                |
|       Editor | Henry Duong <henry@sui.io, @hyd628>                                       |
|         Type | Informational                                                             |
|     Category |                                                                           |
|      Created | 2023-05-26                                                                |
| Comments-URI | https://sips.sui.io/comments-3                                            |
|       Status | Withdrawn                                                                 |
|     Requires |                                                                           |

## Abstract
This proposal suggests the specification of a verification API that verify source code of an on-chain package.

## Motivation
There is currently no way to view the actual source code of an on-chain package if only the package ID is given. Even if the package source code is public, you should download the source code and verify it using the CLI. However, users usually query the package in the SUI explorer. If someone uploads verify the source code once and anyone can view the verified source code in the SUI explorer, it will improve usability and make the network more transparent. The API suggested in this proposal will enable this feature.

## Specification
### REST API
![SIP process diagram](../assets/sip-3/restapi.png)

API Server
1. Explorer calls the verification API.
2. API Server uploads source code to cloud storage.
3. API Server adds the request to a queue.
4. API Server responses the status for checking if the request was accepted.

Batch Server
1. Batch Server reads a bulk of requests in queue.
2. Batch Server downloads source code from cloud storage.
3. Batch Server builds source code and compare with on-chain bytecode.

After that, it saves the result.

- #### 1. Verification Request API
  - #### **Headers**
    - `"Content-Type": "multipart/form-data"`
  
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
      - VERIFIED_ALREADY: The package has already been verified.
      - INTERNAL_ERROR: API Server has internal error.
      - INVALID_FILE: The file is not invalid. (ex. Move.toml non included)

- #### 2. Verification Query API
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
    - **`srcUrl`**: If verified, the download URL for a zip compressed file of source code or null.


### WEBSOCKET
![SIP process diagram](../assets/sip-3/websocket.png)
- #### Upload Source Code and Request Verification
    - #### **Request Event**
      For uploading of the package source code, you should send a request to the websocket endpoint. The event includes fields below.
        - **`network`**: The name of the network where the smart contract is deployed. (ex, mainnet)
        - **`packageId`**: The package ID where the smart contract is deployed.
        - **`suiCliVersion`**: The version of SUI CLI.
        - **`srcCodeZipFile`** : The package source code compressed zip file. (In NodeJS, File type)

    - #### **Response Event**
      The API returns the status of verification. Please note that it does not response the result of verification but the result indicating whether the request has been properly received or not.
        - **`network`**: The name of the network where the smart contract is deployed. (ex, mainnet)
        - **`packageId`**: The package ID where the smart contract is deployed.
        - **`suiCliVersion`**: The version of SUI CLI.
        - **`status`**: Whether it is verified.
          - `VERIFIED_ALREADY`: The package has already been verified.
          - `VERIFIED_SAME`: Received source code is verified.
          - `VERIFIED_DIFFERENT`: Received source code is different with on-chain bytecode.
          - `INTERNAL_ERROR`: API Server has internal error.
          - `INVALID_FILE`: The file is not invalid. (ex. Move.toml non included)
        - **`srcUrl`**: If the status is `VERIFIED_ALREADY` or `VERIFIED_SAME`, the download URL for a zip compressed file of source code or null.

## Rationale
- REST API
  1. API does not return source code string but source download URL because of API response time.
  2. Verification server does not use SUI CLI verify-source command. Instead, it builds with SUI CLI version which is included in the API request. It compares on-chain bytecode and build artifacts. The reason is that this way covers the case that the package address is 0x or published-at is none in Move.toml.
  3. It requires source code storage like AWS S3 because SUI does not store source code in on-chain.
  4. It requires API servers which collect verification requests and query if the package has already been verified. 
  5. It requires verification servers which compile and verify source code.
  6. It requires database which saves verification requests and status.

- Websocket
  1. The code complexity increases compared to the REST API approach.
  2. There is no need for a separate batch server which REST API approach needs.
  
## Backwards Compatibility

There are no issues with backwards compatability.

## Test Cases

## Reference Implementation

## Security Considerations
None

## Copyright
[CC0 1.0](../LICENSE.md).
