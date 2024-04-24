| SIP-Number          | 12                                                        |
| ------------------: | :-------------------------------------------------------- |
| Title               | Poseidon in Sui Move                                      |
| Description         | Add the Poseidon hash function to the Sui Move framework. |
| Author              | Jonas Lindstrøm <@jonas-lj>                               |
| Editor              | Will Riches <will@sui.io, @wriches>                       |
| Type                | Standard                                                  |
| Category            | Framework                                                 |
| Created             | 2023-10-09                                                |
| Comments-URI        | https://sips.sui.io/comments-12                           |
| Status              | Final                                                     |
| Requires            | N/A                                                       |

## Abstract

This SIP introduces a Sui Move framework function which computes the [Poseidon hash function](https://www.poseidon-hash.info/). 


## Motivation

**On-chain verification of zklogin signatures**. The Poseidon hash functions is used in zklogin, so adding Poseidon to the SUI framework is necessary for allowing on-chain verification of zklogin signatures.

**Interoperability with zero-knowledge proof systems**. The Poseidon hash function is a cryptographic hash function designed to be efficient for zero-knowledge proof systems, and is commonly used for ZK applications. It is compatible with all major proof systems (STARKs, SNARKs, Bulletproofs) and there are implementations of 
Poseidon for Circom, Rust, Go, Python and C.

## Specification

We will add the following functions to the Sui Move framework:
```
public fun poseidon_bn254(input: vector<u256>): u256
```
This function between 1 and 32 inputs and is compatible with the implementation of Poseidon in fastcrypto. If more than 
32 inputs are given, the function aborts.

To allow interoperability with other proof systems, we will also add the following functions:
```
public fun poseidon_bls12381(input: vector<u256>): u256
```
This function must be compatible with the official [reference implementation](https://extgit.iaik.tugraz.at/krypto/hadeshash)
for 128 bit security which allows 2 or 4 inputs. If any other number of inputs are given, the function aborts.

The reference implementation also includes parameters for 80 and 256 bit security and for the Ed25519 scalar field, and
these may be added later if needed.

## Rationality

The functionality of the Poseidon hash function is standardized in the [original paper](https://eprint.iacr.org/2019/458.pdf), 
but there are many ways to configure the function: What field is used, how many full and partial rounds, choice of the 
MDS matrix in the linear layer etc., and each configuration yields a new hash function. In this implementation, we will
only use parameters used in the reference implementation and the way it is used in zklogin. This ensures that only
secure choice parameters may be used.

If the only motivation for introducing the Poseidon hash function in Sui Move is to support on-chain verification of
zklogin signatures, implementing Poseidon with the same parameters as used there would be sufficient. However, builders
have expressed interest in using the Poseidon hash function for other purposes, and probably also using other proof 
systems. The above design provides a compromise between convenience and interoperability with any zero-knowledge system, 
a builder could be interested in using with Sui.

The size of the input must be limited because the Poseidon hash functions is rather slow: Hashing 16
elements takes about 0.6ms on a laptop, and the runtime is quadratic in the number of inputs. This is
typically solved by hashing longer inputs using a Merkle tree construction, but this is not standardized, so for the 
BLS12-381 implementation, we will leave this to the builders to define.

## Backwards Compatibility

There are no issues with backwards compatability.

## Reference Implementation


## Security Considerations

The Poseidon hash function is relatively new (introduced 2019) and is less tried-and-tested compared to other hash
functions, so there is a risk that it will be broken. However, it is already used in production by StarkWare, Polygon, 
Dusk Network, Sovrin and Filecoin and has been reviewed by researchers. 

The choice of parameters is important for the security of the Poseidon hash function, but since we only allow the parameters
chosen in the reference implementation, this is not an issue here.

## Copyright

[CC0 1.0](../LICENSE.md).
