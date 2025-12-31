|   SIP-Number | 40                                                                                                                                         |
| -----------: | :----------------------------------------------------------------------------------------------------------------------------------------- |
|        Title | Expose temp_freeze & temp_unfreeze in transfer.move                                                                                        |
|  Description | Allows less frequently updated objects to bypass consensus, which lowers gas, e2e latency & de-coupling of consensus on independent object |
|       Author | Sarthak <sarthak@kriya.finanace @move_og>                                                                                                  |
|       Editor |                                                                                                                                            |
|         Type | Standard                                                                                                                                   |
|     Category | Framework                                                                                                                                  |
|      Created | 2024-08-28                                                                                                                                 |
| Comments-URI |                                                                                                                                            |
|       Status | Draft                                                                                                                                      |

## Abstract

This SIP proposes to extend the freeze_object functionality with temp_freeze & temp_unfreeze in transfer.move

## Motivation

Many complex protocols on Sui are now adopting version management to disable/enable specific versions of list of package ids obtained post package upgrades. Versioning is essential for keeping user funds safe & provides scope for future development on already published packages. Having implemented this design pattern, all funcs are forced to take this Version shared singleton object as input to verify if function in target package is enabled or disabled. This leads to an extra object which will always go through consesnsus, & hence consensus engine end up ordering txns involved with 2 different independent objects but bound by Version object as their common dependency. Similar scenario might arise if a protocol has a GlobalConfig object which stores configs and metadata for the protocol which is less frequently updated. This again ends up with tight coupling on requirement for consensus in using GlobalConfig objects.

The idea is to temporarily freeze objects, which makes it temproarily immutable. As per my knowledge, this would help by-passing the consensus requirement to use this object in read only mode and hence txns on 2 different objects execute in parralel withouth having to acquire locks & consensus for version object as their common dependency.

## Specification

New functions could be added to transfer.move, which can freeze/unfreeze objects as developers want in their respective packages to de-couple consensus requirement from objects which are read-only most of the times as per usage and update frequency.

```rust
module sui::transfer {
    ...

    public fun temp_freeze_object<T: key>(obj: T) {
        temp_freeze_object_impl(obj)
    }

    public fun public_temp_freeze_object<T: key + store>(obj: T) {
        temp_freeze_object_impl(obj)
    }

    public fun temp_unfreeze_object<T: key>(obj: T) {
        temp_unfreeze_object_impl(obj)
    }

    public fun public_untemp_freeze_object<T: key + store>(obj: T) {
        temp_unfreeze_object_impl(obj)
    }

}
```

I'm not sure how impl functions would work behind the scenes, but would appretiate some resources to learn about them.

## Rationale

Sui's object model & consensus engine is unique, but dependencies of functions, on objects as param requirements needs to be handled very carefully which poses challenges to make the protocol leverage best of sui's object modelling.

e.g. KriyaV3 dex & upcoming protocols relies on versioning of objects.

As per current design,
public fun swap<A, B>(pool: &mut Pool<A, B>, version: &Version) { ... }

if this func is called by 2 different instances of pool, for txn ordering consensus might be required on Version object since it's not immutable. And txns cannot execute in parrallel & gas costs will be relatively higher.

## Backwards Compatibility

I don't see any issue regarding backwards compatibility if we introduce a new state(TempFreezed) in which object becomes partially immutable. Object marked as immutable already on mainnet wont have issues since only a new state of the object has been introduced.

## Security Considerations

Adding new states for objects must require extensive testing on testnet. I would be happy to help testing on testnet.
