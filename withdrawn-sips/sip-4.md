|   SIP-Number | 4                                                                              |
|-------------:|:-------------------------------------------------------------------------------|
|        Title | Dependency Update Check API                                                    |
|  Description | A standard protocol for the API that checks the latest version of a dependency |
|       Author | kairoski03                                                                     |
|       Editor | Henry Duong <henry@sui.io, @hyd628>                                            |
|         Type | Informational                                                                  |
|     Category |                                                                                |
|      Created | 2023-06-01                                                                     |
| Comments-URI | https://sips.sui.io/comments-4                                                 |
|       Status | Withdrawn                                                                      |
|     Requires |                                                                                |

## Abstract
This proposal suggests specifying an API that enables checking whether the versions of package dependencies have been updated.

## Motivation
If a dependency module had a security bug or a logical bug and a fixed version has been released, it is crucial to consider upgrading your module to the latest version of the dependency. However, there is no straightforward way to comprehensively grasp the latest version of a dependency package.

## Specification

### **Request**

To check if new version of your dependencies has been released, you should send a **`GET`** request to the API endpoint. The required parameters are below.

- **`network`**: The name of the network where the smart contract is deployed. (ex, mainnet)
- **`packageId`**: The package ID where the smart contract is deployed.

### **Response**

The API returns the result including below fields:

```json
{
  "network": "mainnet",
  "packageId": "4eb6fdf0e8d4cf9503c20ef51a8b9b8f01c2fc118b6cb85a978b6638800ce27f",
  "modules": [
    {
      "module": "forge_call",
      "dependencies": [
        {
          "packageId": "0xe4b7c26c1bd06b91aa8700d776e10e05767a50ae294372b431305cb8205a3f7f",
          "module": "forge",
          "upgradeCapId": "0x82eff1411f4aec5476d1e615b08f8cacabff74619e2cd70c6c25485a4c3e2bc9",
          "current": {
            "packageId": "0xe4b7c26c1bd06b91aa8700d776e10e05767a50ae294372b431305cb8205a3f7f",
            "version": 1
          },
          "latest": {
            "packageId": "0xf4fdd76706a27788a2c93adcd12bb2b888dc2f36ee84ca94d68910f2f671bf17",
            "version": 2
          }
        }
      ]
    }
  ]
}
```

## Rationale
- Currently, obtaining the latest package version requires making multiple JSON-RPC calls such as sui_getObject, sui_multiGetObjects, and sui_getTransactionBlock.
- When an UpgradeCap is deleted, it becomes challenging to identify the latest version since it involves searching through the transactions of the package owner and locating the relevant one.

## Backwards Compatibility

There are no issues with backwards compatability.

## Test Cases

## Reference Implementation

## Security Considerations
None

## Copyright
[CC0 1.0](../LICENSE.md).
