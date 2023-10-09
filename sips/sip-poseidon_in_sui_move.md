| SIP-Number          |                                                                                                                                            |
| ---:                |:-------------------------------------------------------------------------------------------------------------------------------------------|
| Title               | Poseidon in SUI move                                                                                                                       |
| Description         | Add the Poseidon hash function to the SUI Move framework.                                                                                  |
| Author              | Jonas Lindstrøm (jonas-lj)                                                                                                                 |
| Editor              |                                                                                                                                            |
| Type                | Standard                                                                                                                                   |
| Category            | Framework                                                                                                                                  |
| Created             | 2023-10-09                                                                                                                                 |
| Comments-URI        |                                                                                                                                            |
| Status              |                                                                                                                                            |
| Requires            |                                                                                                                                            |

## Abstract

This SIP introduces a SUI Move framework function which computes the [Poseidon hash function](https://www.poseidon-hash.info/). 


## Motivation

**On-chain verification of zklogin signatures**. The Poseidon hash functions is used in zklogin, so adding Poseidon to the SUI framework is necessary for allowing on-chain verification of zklogin signatures.

**Interoperability with zero-knowledge proof systems**. The Poseidon hash function is a cryptographic hash function designed to be efficient for zero-knowledge proof systems, and is commonly used for ZK applications. It is compatible with all major proof systems (STARKs, SNARKs, Bulletproofs) and there are implementations of 
Poseidon for Circom, Rust, Go, Python and C.

## Specification

The following function will be added to the SUI Move framework under the `sui::poseidon` module:
```
pub fun poseidon(
	prime_field_modulus: u256, // Modulus of prime field
	security_level: u16,       // Security level
	alpha: u8,                 // Power of s-box
	state_size: u8,            // Size of internal state
	full_rounds: u8,           // Number of full rounds
	partial_rounds: u8,        // Number of partial rounds
	mds: vector<vector<u256>>, // An MDS matrix of size state_size x state_size
	input: vector<u256>,       // Input to the hash function
): u256
```
This will compute the Poseidon hash function as specified in the [Poseidon paper](https://eprint.iacr.org/2019/458.pdf) 
and return the hash. If the input is larger than 16, the functions aborts with an error code.

The same module will also have a convenience function for Poseidon with the parameters used in zklogin:
```
public fun poseidon_bn254(input: vector<u256>): u256
```
Other functions with different parameters may be added in the future as they are needed.

## Rationality

The functionality of the Poseidon hash function is standardized in the [original paper](https://eprint.iacr.org/2019/458.pdf), 
vut there are many ways to configure the function: What field is used, how many full and partial rounds, choice of the 
MDS matrix in the linear layer etc., and each configuration yields a new hash function.

If the only motivation for introducing the Poseidon hash function in SUI move is to support on-chain verification of
zklogin signatures, implementing Poseidon with the same parameters as used there would be sufficient. However, builders
have expressed interest in using the Poseidon hash function for other purposes, and probably also using other proof 
systems, and the function will have to be generic to support this. The above design provides a compromise between 
convenience and interoperability with any zero-knowledge system, a builder could be interested in using with SUI.

The size of the input must be limited to 16 because the Poseidon hash functions is rather slow: Hashing 16
elements takes about 0.6ms on a laptop, and the runtime is quadratic in the number of inputs. This is
typically solved by hashing longer inputs using a Merkle tree construction.

## Backwards Compatibility

There are no issues with backwards compatability.

## Reference Implementation
The convenience function for Poseidon with the parameters used in zklogin is implemented like this:
```
public fun poseidon_bn254(input: vector<u256>): u256 {
	let input_size = vector::length(input);
	poseidon(
		16798108731015832284940804142231733909889187121439069848933715426072753864723u256,
		128,
		5,
		input_size + 1,
		8,
		vec![
            56, 57, 56, 60, 60, 63, 64, 63, 60, 66, 60, 65, 70, 60, 64, 68,
        ][input_size],
        input
	)
}
```

## Security Considerations

While the Poseidon hash function is relatively new (introduced 2019) and is less tried-and-tested compared to other hash
functions, it is already used in production by StarkWare, Polygon Dusk Network, Sovrin and Filecoin and has been
. 

The choice of parameters is important for the security of the Poseidon hash function. The functions in this SIP allow
any parameters, but the documentation should clearly state how to choose secure parameters and recommend using one of 
the convenience functions with already chosen secure parameters.

## Copyright

[CC0 1.0](../LICENSE.md).