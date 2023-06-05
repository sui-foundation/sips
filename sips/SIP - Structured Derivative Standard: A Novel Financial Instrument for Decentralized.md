| SIP-Number          | <Leave this blank; it will be assigned by a SIP Editor> |
| ---:                | :--- |
| Title               | Structured Derivative Standard: A Novel Financial Instrument for Decentralized Finance on Sui |
| Description         | Introduction of a pioneering Structured Derivative Standard in the realm of blockchain, enabling time-varying functionalities and asset encapsulation, paving the way for mainstream finance instruments like CDOs, MBS on Sui. |
| Author              | [Torai.money](https://torai.money/) team |
| Editor              | <Leave this blank; it will be assigned by a SIP Editor> |
| Type                | Standard |
| Category            | Framework |
| Created             | 2023-06-05 |
| Comments-URI        | <Leave this blank; it will be assigned by a SIP Editor> |
| Status              | <Leave this blank; it will be assigned by a SIP Editor> |
| Requires            | None|

## Abstract

The Structured Derivative Standard is a groundbreaking asset standard for decentralized finance protocols on the Sui blockchain. It allows for the encapsulation of varying types of assets and the tracking of functionality over time. This standard introduces mainstream financial instruments, such as Collateralized Debt Obligations (CDOs) and Mortgage-Backed Securities (MBS), into the decentralized finance sphere for the first time.

## Motivation

Decentralized finance protocols have struggled to incorporate the complex financial instruments common in traditional finance, mainly due to difficulties in performing time-related computations. These computations, essential for instruments like lending protocols, have posed a significant challenge in decentralized finance. The Structured Derivative Standard addresses this gap, leveraging blockchain's unique strengths to facilitate complex financial transactions involving time-dependent parameters.

## Specification

The Structured Derivative Standard leverages ZK-snarks to ensure privacy and security, facilitates the packing and redeeming of any type of asset, and enables dividend tracking, regardless of how many times the financial instrument has been transferred. Assets and functionalities are stored in a Merkle tree, with leaves representing different assets. A time-varying function computation is written onto a ZK-snark tree on-chain.
The code below outlines the general structure of these computations:

```python

// Define the function
Function TimeVaryingFunction(asset, time)
{
  // Compute time-varying functionality based on the specific asset and time
  value = ComputeFunctionality(asset, time);

  // Write value to the ZK-snark tree
  zkTree.WriteValue(asset, value);
}

// Iterate over all assets and times
For each asset in assets
{
  For each time in times
  {
    // Logic to handle time-varying characteristics
    If (asset.type == 'bond' AND time <= asset.maturity)
    {
      asset.value = asset.faceValue * e^(asset.interestRate * time);
    }
    ElseIf (asset.type == 'option' AND time <= asset.expiry)
    {
      asset.value = max(asset.strikePrice - asset.underlyingAsset.value, 0);
    }
    Else
    {
      asset.value = asset.initialValue;
    }

    // Call TimeVaryingFunction to write the value to ZK-snark tree
    TimeVaryingFunction(asset, time);
  }
}

```

This process allows the system to track the evolution of assets over time, providing a dynamic picture of their performance and value.

## Rationale

The design of the Structured Derivative Standard is driven by the need to bring more complex financial instruments into the decentralized finance sphere. It is particularly targeted at solving the challenges of time-related computations that have limited the expansion and sophistication of decentralized finance protocols. By combining the flexible, transparent, and secure nature of blockchain technology with the sophisticated financial instruments of traditional finance, the Structured Derivative Standard offers a practical solution to a long-standing problem.

## Backwards Compatibility

The Structured Derivative Standard is designed to be compatible with existing decentralized finance protocols on the Sui blockchain. It does not introduce any backwards incompatibilities.

## Test Cases

(This section can be expanded upon as the SIP progresses and specific test cases are formulated.)

## Security Considerations

None
