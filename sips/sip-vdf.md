| SIP-Number          | <Leave this blank; it will be assigned by a SIP Editor> |
| ```:                | :``` |
| Title               | Introduction of Verifiable Delay Functions (VDFs) to Sui Framework |
| Description         | Add verifiable delay functions (VDFs) to the Sui framework. |
| Author              | Jonas Lindstrøm (@jonas-lj) |
| Editor              | <Leave this blank; it will be assigned by a SIP Editor> |
| Type                | Standard |
| Category            | Framework |
| Created             | 2024-08-08 |
| Comments-URI        | <Leave this blank; it will be assigned by a SIP Editor> |
| Status              | <Leave this blank; it will be assigned by a SIP Editor> |
| Requires            | |


## Abstract
```
This SIP proposes the introduction of Verifiable Delay Functions (VDFs) into the Sui framework. VDFs are cryptographic primitives that require a predetermined amount of time to compute and are efficiently verifiable.

```

## Motivation
```
### 1. **Improved Randomness:**
   - **Unbiased and Verifiable Randomness:** VDFs can be used to generate verifiable randomness that is resistant to manipulation, which is critical for applications like lottery systems, cryptographic protocols, and decentralized governance.

### 2. **Enhanced Security and Fairness:**
   - **Prevent Front-Running:** In decentralized systems, particularly in financial applications, front-running is a significant issue where attackers exploit information by placing transactions ahead of others. VDFs can mitigate front-running by delaying the revelation of critical information until it can no longer be exploited.

### 3. **Increased Trust and Decentralization:**
   - **Trustless and Transparent Systems:** By introducing VDFs, the Sui blockchain can build more trustless and transparent systems where the outcome of certain processes is provably delayed and verified, removing the need for trust in third parties.
```

## Specification
```
   The integration of VDFs into the Sui framework will involve the following key components:

   - **Smart Contract Support:** The Sui Move language will be extended to support VDF operations (verification) within smart contracts. This will allow developers to incorporate delay functions directly into their decentralized applications (dApps).
   - **VDF Computation Engine:** A modular VDF computation engine will be integrated into fastcrypto for off-chain evaluation of a VDF.
```

### 2. **Implementation Details:**
```
   - **Algorithm Selection:** Initially, Wesolowski's VDF scheme is recommended due to its balance of efficiency and security. However, the framework should be modular to allow future inclusion of other VDF schemes, in particular Pietrzak's construction.
   - **Evaluation:** Evaluating the VDF is supposed to happen off-chain, so we must create tooling for this or extend use (and possibly extend) implementations, such as chiavdf.
   - **Verification**: Verifying the VDF must be possible onchain for dApps to verify and use the output.
   - **Gas Costs:** A gas cost model for VDF operations will be developed to ensure that the computational overhead of VDFs is appropriately accounted for in transaction fees.
```

## Rationale
```
The rationale for introducing VDFs into the Sui framework is grounded in the growing need for secure, fair, and decentralized systems. By leveraging VDFs, the Sui blockchain can address current limitations related to randomness generation, leader election, and front-running attacks. The integration of VDFs aligns with the broader goals of enhancing trust, security, and decentralization in the Sui ecosystem.

```

## Backward Compatibility
```
The proposed integration of VDFs will be backward-compatible. Existing smart contracts and decentralized applications (dApps) on the Sui network will continue to function without modification.
```

## Test Cases
```
### 1. **VDF Computation and Verification:**
   - Test the accuracy and efficiency of VDF computation and verification under various network conditions.
   - Validate the correctness of the VDF output and its verification process.

### 2. **VDF-Based Randomness Generation:**
   - Implement a VDF-based randomness beacon and evaluate its performance in generating unbiased and verifiable randomness.
   - Test the integration of VDF-based randomness in lottery smart contracts and other decentralized applications.

```

## Implementation
```
The implementation of VDFs in the Sui framework will proceed in phases:

1. **Research and Selection Phase:**
   - Conduct a comprehensive analysis of existing VDF schemes and select the most suitable one(s) for integration into Sui.
   
2. **Development Phase:**
   - Develop and integrate the VDF evaluation and verification modules, and smart contract support into the Sui framework.
   
3. **Testing Phase:**
   - Rigorously test the VDF implementation under various scenarios to ensure security, efficiency, and reliability.
   
4. **Deployment Phase:**
   - Deploy the VDF components to the Sui mainnet, along with documentation and developer guides.

```

## Security Considerations
```
Introducing VDFs into the Sui framework necessitates a thorough evaluation of the security implications. The selected VDF scheme must be resistant to potential attacks, and the implementation should be carefully audited. Additionally, the gas cost model for VDFs must be carefully calibrated to prevent denial-of-service (DoS) attacks.

```

## Conclusion
```
The integration of Verifiable Delay Functions (VDFs) into the Sui framework represents a significant advancement in enhancing the security, fairness, and robustness of the Sui blockchain. By addressing critical challenges related to randomness generation, leader election, and front-running, VDFs will contribute to the long-term success and trustworthiness of the Sui ecosystem.

```

## References
```
1. Wesolowski, B. (2019). "Efficient Verifiable Delay Functions."
2. Pietrzak, K. (2019). "Simple Verifiable Delay Functions."
3. Boneh, D., & Bonneau, J. et al. (2018). "Verifiable Delay Functions."

```

## Copyright
```
This document is licensed under the Creative Commons Attribution 4.0 International (CC BY 4.0) License.
```