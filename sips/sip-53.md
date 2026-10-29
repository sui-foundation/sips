|   SIP-Number | 53 ||         ---: | :--- |
|        Title | `singleton` ability |
|  Description | Adds the `singleton` ability to enforce single-instance objects |
|       Author | Kevin \<github@aftermath.finance, @admin-aftermath\>, Aftermath Finance \<[aftermath.finance](https://aftermath.finance/)\> |
|       Editor | TBD |
|         Type | Standard |
|     Category | Framework |
|      Created | 2024-02-25 |
| Comments-URI | TBD |
|       Status | Draft |
|     Requires | N/A |

## Abstract

This SIP proposes a new ability modifier to Move: `singleton`. The `singleton` ability enforces that *at most* one instance of a type can ever be created, providing strong guarantees about type uniqueness that are enforced within Sui's bytecode verifier.

This ability is particularly impactful for domain-critical objects, such as capability objects (e.g., `AdminCap`) or one-of shared configuration objects, where ensuring a single instance is crucial to maintain both system integrity and full transparency behind the control of the smart contracts. By leveraging the `singleton` ability, developers can create more secure and trustless Sui-based applications that prevent the accidental or malicious duplication of key types.

> As Sui will continue to evolve over time, a snapshot of the Sui repo will be used when referencing Sui Framework code. This SIP uses the latest stable version of mainnet: `mainnet-v1.42.2`.<sup>[1](https://github.com/MystenLabs/sui/tree/mainnet-v1.42.2)</sup>

> This SIP has been implemented, albeit the implementation can be improved, and can be found in our [fork](https://github.com/AftermathFinance/sui-public/tree/sip/singleton-ability) of the Sui repo.<sup>[2](https://github.com/AftermathFinance/sui-public/tree/sip/singleton-ability)</sup>

## Background

**Abilities.** Move defines four ability modifiers that can be applied to structs and modify how the type can be interacted with. The four abilities currently supported by [all dialects of] Move are:
 - `copy`: Allows structs to be copied (i.e., duplicated).
 - `drop`: Allows structs to be dropped (i.e., deleted without explicit unpacking).
 - `key`: Designates the struct as an object, enabling it to be uniquely identified and serve as a top-level element in Sui's object storage.
 - `store`: Enables structs with this ability to be stored as fields within other structs in Sui's object storage. Additionally, structs with the `store` ability can be transferred using Sui's `0x2::transfer::public_transfer` function.

More info on Move's abilities can be found in the [Move Book](https://move-book.com/move-basics/abilities-introduction.html?highlight=abilities#what-are-abilities) and the [Move Reference](https://move-book.com/reference/abilities.html).<sup>[3](https://move-book.com/move-basics/abilities-introduction.html?highlight=abilities#what-are-abilities)[4](https://move-book.com/reference/abilities.html)</sup>

**One-Time Witness.** Sui Move defines a custom type: the [one-time witness (OTW)](https://move-book.com/programmability/one-time-witness.html?highlight=one#one-time-witness).<sup>[5](https://move-book.com/programmability/one-time-witness.html?highlight=one#one-time-witness)</sup> OTWs are special types of witnesses that, among other restrictions, can only be instantiated once and only during a module's `init` function. They are used to provide assurance that a specific action (e.g., creating a `TreasuryCap`) is only performed once.

&nbsp;&nbsp;&nbsp;&nbsp; This restriction is enforced directly by Sui's bytecode verifier through a custom one-time witness verifier rule.<sup>[6](https://github.com/MystenLabs/sui/blob/mainnet-v1.42.2/sui-execution/latest/sui-verifier/src/one_time_witness_verifier.rs)</sup>

**Singletons.** Singletons are data structures that can have only one instance. They are used to provide a global point of access to a resource or service and ensure that only the one instance of the resource exists throughout the system. In the context of Sui, a singleton is a type (or object if paired with the `key` ability) that has at most one instantiation.

## Motivation

**Singleton Objects.** There are many reasons why singletons are useful in Sui:
 * **Both as a user and as a developer**, I want assurance that the capability objects behind the smart contracts I interact with are unique and cannot be duplicated. Most packages use capability objects (e.g., `AdminCap`) to gate permissioned actions and only one address (potentially a Sui native multisig) has access to these objects. Currently, there is no way to guarantee *at the type system level* that only one such capability object exists.
 * **Both as a user and as a developer**, I want assurance that the third party, domain-critical objects I interact with are in fact unique. Packages often use one-of shared objects to store protocol-specific parameters (e.g., fee rates); the `singleton` ability would ensure that there can only be one canonical instantiation of this object, preventing potential exploits through duplicate instances.
 * **As a developer**, I strive for both greater transparency and want to ensure the domain-critical objects I create are unique.

**Limitations.** While one-time witnesses provide a way to create single-instance types, they are too restrictive to enable singleton objects. Specifically, one-time witnesses:
 1. Cannot have the `key` or `store` abilities.
 1. Cannot have any type arguments.
 1. Rely on a strict naming convention.
 1. Need to be unpacked to claim a modules `Publisher` object.
&nbsp;&nbsp;&nbsp;&nbsp; This creates challenges when developing systems that require *strong* guarantees about object uniqueness throughout system's lifecycle.

**Workarounds.** To get around these limitations, I've adopted this simple design pattern to emulate singleton-esque restriction for our objects:
```move
/// Create the packages unique `AdminCap` object.
///
/// Aborts:
///   i. [<package>::admin::EAdminCapAlreadyCreated]
public(package) fun create_admin_cap<T: drop>(
    witness: &T,
    ctx: &mut TxContext
): AdminCap {
    // i. `public(package)` + this check guarantee that this function is being called from this
    // packages `init` function only, asserting that no two `AdminCap`'s can ever exist.
    assert!(is_one_time_witness(witness), EAdminCapAlreadyCreated);

    AdminCap {
        id: ctx.new_uid(),
    }
}
```

&nbsp;&nbsp;&nbsp;&nbsp; This pattern functionally works, but requires those who interact with your package to trust that the `assert!(is_one_time_witness(witness), ...)` will not be removed in a future package upgrade. Any layer of trust that is required between users and dApps is a layer of trust that can be exploited.

## Prerequisites

There are no prerequisites for this SIP.

## Specification

The Move language will be extended with the `singleton` ability. The `singleton` ability will provide the following invariants:
 1. At most one instance of a struct with the `singleton` ability can ever be created.
 1. The `singleton` ability is mutually exclusive with the `copy` ability, meaning that objects with the `singleton` ability cannot be copied or duplicated.
 1. The creation of a struct with a `singleton` ability must occur within a package's `init` function. (A secondary implementation is suggested within the **Secondary Implementation** that can alleviate this constraint).
These constraints will be enforced directly within Sui's bytecode verifier.

Similarly, `tree-sitter-move` will be extended to support the `singleton` ability.

Lastly, the following warnings and errors will be added to the Move compiler:
 * `singleton_not_created`: Warns when a `singleton` object is not created within a package's `init` function.
    * The annotation (`#[allow(lint(singleton_not_created))`) will be added to prevent warnings in the case a packages `init` is removed or altered after the module has been published.
 * `singleton_drop_ability`: Warns when a struct is defined as having both the `singleton` and `drop` abilities as dropping a `singleton` type will drop it forever.
 * `singleton_copy_generic_type`: Errors when generic types are specified to have `copy + singleton` abilities; e.g., `<T: copy + singleton`>.
 * `singleton_created_outside_init`: Errors when a `singleton` object is created outside of a package's `init` function.
 * `singleton_copy_ability`: Errors when a struct is defined as having both the `singleton` and `copy` abilities.
 * `singleton_already_exists`: Errors when a `singleton` type is instantiated more than once.

## Rationale

The `singleton` ability provides a more robust solution to the problems outlined in **Background**. Objects that should only ever have one instance can now be defined with the `singleton` ability to move this enforcement to Sui's bytecode verifier. This enables a more trustless relationship between users <> dApps and developers <> third-party dependencies and prevents vulnerabilities related to the malicious creation of should-be-singleton objects.

## Backwards Compatibility

This SIP presents no issues with backwards compatibility.

## Reference Implementation

I have created a fork of the Sui repo to implement the `singleton` ability; the relevant changes are detailed below. There are a lot of similar changes across a series of files, for brevity, I have only shown the most prominent changes. View our fork for the full implementation.

### i. Changes to the Move AST

### ia. `external-crates/move/crates/move-compiler/src/parser/ast.rs`

We need to add the `singleton` ability to Move's AST, so `singleton` is correctly recognized as an ability.

```rust
impl Ability_ {
    ...

    pub const SINGLETON: &'static str = "singleton";

    /// For a struct with ability `a`, each field needs to have the ability `a.requires()`.
    /// Consider a generic type Foo<t1, ..., tn>, for Foo<t1, ..., tn> to have ability `a`, Foo must
    /// have been declared with `a` and each type argument ti must have the ability `a.requires()`
    pub fn requires(self) -> Vec<Ability_> {
        match self {
            Ability_::Copy => vec![Ability_::Copy],
            Ability_::Drop => vec![Ability_::Drop],
            Ability_::Store => vec![Ability_::Store],
            Ability_::Key => vec![Ability_::Store],
            Ability_::Singleton => vec![],
        }
    }

    /// An inverse of `requires`, where x is in a.required_by() iff x.requires() == a
    pub fn required_by(self) -> Vec<Ability_> {
        match self {
            ...

            Self::Singleton => vec![],
        }
    }
}
```

The `singleton` struct does not require its fields to have any ability, so the `requires` function needs to be updated to return a `Vec<Ability_>` and for `Ability_::Singleton` it will return an empty vec. This change forces many changes across the Move compiler, these changes have been left out of the discussion of the **Reference Implementation**.

### ib. `external-crates/move/crates/move-compiler/src/parser/syntax.rs`

The parser needs to be updated to convert the `singleton` token into the `singleton` ability.

```rust
fn token_to_ability(token: Tok, content: &str) -> Option<Ability_> {
    match (token, content) {
        ...

        (Tok::Identifier, Ability_::SINGLETON) => Some(Ability_::Singleton),
        _ => None,
    }
}
```

### ic. `external-crates/move/crates/move-compiler/src/to_bytecode/translate.rs`

We need to update the `ability` conversion function to correctly convert between AST and IR.

```rust
fn ability(sp!(_, a_): Ability) -> IR::Ability {
    use Ability_ as A;
    use IR::Ability as IRA;
    match a_ {
        ...

        A::Singleton => IRA::Singleton,
    }
}
```

### id. `external-crates/move/crates/move-compiler/src/expansion/ast.rs`

The AST `AbilitySet` representation needs to be updated to include the `singleton` ability in its `ALL` vector.

```rust
impl AbilitySet {
    /// All abilities
    pub const ALL: [Ability_; 5] = [
        ...

        Ability_::Singleton,
    ];

    ...
}
```

### ii. Changes to the Move IR

### iia. `external-crates/move/crates/move-ir-types/src/ast.rs`

```rust
/// The abilities of a type. Analogous to `move_binary_format::file_format::Ability`.
#[derive(Debug, Clone, Eq, Copy, Hash, Ord, PartialEq, PartialOrd)]
pub enum Ability {
    ...

    /// Allows there to only exist one instance of the type in global storage
    Singleton,
}

...

impl Ability {
    ...

    pub const SINGLETON: &'static str = "singleton";
}

...

impl fmt::Display for Ability {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "{}",
            match self {
                ...

                Ability::Singleton => Ability::SINGLETON,
            }
        )
    }
}
```

### iib. `external-crates/move/crates/move-ir-to-bytecode-syntax/src/syntax.rs`

```rust
fn token_to_ability(token: Tok, contents: &str) -> Option<Ability> {
    match (token, contents) {
        ...

        (Tok::NameValue, Ability::SINGLETON) => Some(Ability::Singleton),
    }
}
```

### iic. `external-crates/move/crates/move-ir-to-bytecode/src/compiler.rs`

```rust
fn ability(ab: &ast::Ability) -> Ability {
    match ab {
        ...

        ast::Ability::Singleton => Ability::Singleton,
    }
}
```

### iii. Changes to `move-binary-format`

### iiia. `external-crates/move/crates/move-binary-format/src/file_format.rs`

We need to add the `Singleton` variant to the `Ability` enum:

```rust
pub enum Ability {
    ...

    /// Enforces the type to have at most one instance in global storage
    Singleton = 0x10,
}

impl Ability {
    fn from_u8(u: u8) -> Option<Self> {
        match u {
            ...

            0x10 => Some(Ability::Singleton),
            _ => None,
        }
    }

    /// For a struct with ability `a`, each field needs to have the ability `a.requires()`.
    /// Consider a generic type Foo<t1, ..., tn>, for Foo<t1, ..., tn> to have ability `a`, Foo must
    /// have been declared with `a` and each type argument ti must have the ability `a.requires()`
    pub fn requires(self) -> AbilitySet {
        match self {
            Self::Copy => AbilitySet::EMPTY | Ability::Copy,
            Self::Drop => AbilitySet::EMPTY | Ability::Drop,
            Self::Store => AbilitySet::EMPTY | Ability::Store,
            Self::Key => AbilitySet::EMPTY | Ability::Store,
            Self::Singleton => AbilitySet::EMPTY,
        }
    }

    /// An inverse of `requires`, where x is in a.required_by() iff x.requires() == a
    pub fn required_by(self) -> AbilitySet {
        match self {
            ...

            Self::Singleton => AbilitySet::EMPTY,
        }
    }

    ...
}

impl Display for Ability {
    fn fmt(&self, f: &mut Formatter) -> std::fmt::Result {
        match self {
            ...

            Ability::Singleton => write!(f, "singleton"),
        }
    }
}
```

As with the AST's `requires` function, the above `requires` function needs to be updated to return `AbilitySet`. Before `singleton` there is a struct 1:1 mapping between the input to and output of `requires`. This is no longer the case, as `singleton` does not require any other abilities. Returning `AbilitySet` is also future proof as it enables the addition of further abilities that might require any subset of the existing abilities.

`AbilitySet` also needs to be updated to accommodate the new `singleton` ability:

```rust
impl AbilitySet {
    ...

    /// Ability set containing all abilities
    pub const ALL: Self = Self(
        // Cannot use AbilitySet bitor because it is not const
        (Ability::Copy as u8)
            | (Ability::Drop as u8)
            | (Ability::Store as u8)
            | (Ability::Key as u8)
            | (Ability::Singleton as u8),
    );

    ...

    pub fn has_singleton(self) -> bool {
        self.has_ability(Ability::Singleton)
    }

    ...
}
```
Finally, `AbilitySetIterator` also needs to be updated to account for `singleton` being represented with `0x10`:

```rust
impl Iterator for AbilitySetIterator {
    type Item = Ability;

    fn next(&mut self) -> Option<Self::Item> {
        while self.idx <= 0x10 /* <---- was previously 0x8 */ {
            let next = Ability::from_u8(self.set.0 & self.idx);
            self.idx <<= 1;
            if next.is_some() {
                return next;
            }
        }
        None
    }
}
```

### iv. Changes to the Move bytecode verifier

### iva. `sui-execution/latest/sui-verifier/src/struct_with_singleton_verifier.rs`

The `singleton` type requires invariants that need to be baked into the Move bytecode verifier. First we need to add the actual invariants to the `sui-verifier` crate.

```rust
//! This verifier ensures that types with the `singleton` ability are properly handled.
//! A singleton type can be instantiated at most once and only during the module's initialization.
//!
//! # Key properties enforced:
//! - Types with the singleton ability can only be instantiated in a module's `init` function.
//! - For each struct with the singleton ability, at most one of that type can be instantiated.
//! - Types with the singleton ability cannot have the `copy` ability.

use move_binary_format::file_format::{Bytecode, CompiledModule, StructDefinition};
use sui_types::error::ExecutionError;
use std::collections::HashMap;

use crate::{verification_failure, INIT_FN_NAME};

/// Verifies that all singleton types in the module follow singleton rules
pub fn verify_module(module: &CompiledModule) -> Result<(), ExecutionError> {
    let singletons = get_singletons(module);
    if singletons.is_empty() {
        return Ok(());
    }

    verify_singleton_constraints(module, &singletons).map_err(verification_failure)
}

/// Collects all struct types that have the singleton ability
fn get_singletons(module: &CompiledModule) -> Vec<(String, StructDefinition)> {
    module
        .struct_defs
        .iter()
        .filter_map(|def| {
            let handle = module.datatype_handle_at(def.struct_handle);
            if handle.abilities.has_singleton() {
                let name = module.identifier_at(handle.name).to_string();
                Some((name, def.clone()))
            } else {
                None
            }
        })
        .collect()
}

/// Verifies that singleton types are only instantiated in init and at most once and do not
/// have the `copy` ability.
fn verify_singleton_constraints(
    module: &CompiledModule,
    singletons: &[(String, StructDefinition)],
) -> Result<(), String> {
    // Track Pack operations for each singleton type
    let mut pack_counts: HashMap<&str, usize> =
        singletons.iter().map(|(name, _)| (name.as_str(), 0)).collect();

    verify_no_singleton_has_the_copy_ability(module, singletons)?;

    for fn_def in &module.function_defs {
        let fn_handle = module.function_handle_at(fn_def.function);
        let is_init = module.identifier_at(fn_handle.name) == INIT_FN_NAME;

        if let Some(code) = &fn_def.code {
            verify_function_bytecode(module, singletons, &mut pack_counts, code, is_init)?;
        }
    }

    Ok(())
}

fn verify_no_singleton_has_the_copy_ability(
    module: &CompiledModule,
    singleton_structs: &[(String, StructDefinition)],
) -> Result<(), String> {
    singleton_structs
        .iter()
        .find(|(_, def)| module.datatype_handle_at(def.struct_handle).abilities.has_copy())
        .map_or(Ok(()), |(name, _)| {
            Err(format!(
                "Singleton type {}::{} cannot have the copy ability",
                module.self_id(),
                name
            ))
        })
}

/// Verifies Pack operations for singleton types occur only in the init function and at most once
fn verify_function_bytecode(
    module: &CompiledModule,
    singletons: &[(String, StructDefinition)],
    pack_counts: &mut HashMap<&str, usize>,
    code: &move_binary_format::file_format::CodeUnit,
    is_init: bool,
) -> Result<(), String> {
    for bcode in &code.code {
        if let Bytecode::Pack(idx) = bcode {
            let packed_def = module.struct_def_at(*idx);

            // Check each singleton type
            for (name, def) in singletons {
                if packed_def == def {
                    // Verify Pack location
                    if !is_init {
                        return Err(format!(
                            "Singleton type {}::{} can only be instantiated in the init function",
                            module.self_id(),
                            name
                        ));
                    }

                    // Update and verify count
                    let count = pack_counts.get_mut(name.as_str()).unwrap();
                    *count += 1;
                    if *count > 1 {
                        return Err(format!(
                            "Singleton type {}::{} can be instantiated at most once",
                            module.self_id(),
                            name,
                        ));
                    }
                }
            }
        }
    }

    Ok(())
}
```

The above is an implementation of the `verify_module` function that ensures the `singleton` ability is correctly handled. The function first collects all structs with the `singleton` ability, then verifies that these structs are only instantiated in the module's `init` function and at most once. The function also ensures that structs with the `singleton` ability do not have the `copy` ability.

### ivb. `sui-execution/latest/sui-verifier/src/verifier.rs`

Next we need to make sure the new `verify_module` function is called:

```rust
pub fn sui_verify_module_metered(
    module: &CompiledModule,
    fn_info_map: &FnInfoMap,
    meter: &mut (impl Meter + ?Sized),
    verifier_config: &VerifierConfig,
) -> Result<(), ExecutionError> {
    ...

    struct_with_singleton_verifier::verify_module(module)
}
```

### v. Changes to `tree-sitter-move`

The final step I will mention is updating `tree-sitter` support for Move to enable syntax highlighting for the `singleton` ability. To do so, the `singleton` ability needs to be added to the list of known abilities.

```rust
    ...

    ability: $ => choice(
      ...

      'singleton',
    ),

    ...
```

## Secondary Implementation

There are cases where the `init` function constraint is too restrictive; I will suggest a secondary implementation that can alleviate this constraint if the general consensus is against it.

### i. Create a `singleton` module in the Sui Framework

```move
module singleton;

use std::type_name;

use fun sui::dynamic_field::exists_ as UID.has_registered;
use fun sui::dynamic_field::add as UID.register;

const ENotSystemAddress: u64 = 0;
// #[error]
// const ESingletonAlreadyExists: vector<u8> = b"The Singleton type has already been created.";
const ESingletonAlreadyExists = 0x1;

public struct SingletonRegistry has key, singleton {
    id: UID,
    // versioning field iff similar `SingletonRegistryInner` setup is required.,
}

/// Track a new singleton `TypeName` within the `SingletonRegistry` marking its one and only instantiation.
public fun register<T: singleton>(
    registry: &mut SingletonRegistry,
    singleton: &T,
) {
    let type_name = type_name::get<T>();
    assert!(!registry.id.has_registered(type_name), ESingletonAlreadyExists);

    //
    registry.id.register(type_name, /* `Value` type doesn't matter */);
}

fun create(ctx: &TxContext) {
    assert!(ctx.sender() == @0x0, ENotSystemAddress);

    let self = SingletonRegistry {
        id: object::singleton_registry(), // 0x10
    };

    transfer::share_object(self);
}
```

### ii. Modify the `verify_module` + family of functions.

Instead of the `is_init` assertion, we should replace it with a check enforcing the pack operation is followed by a call to `sui::singleton::register` that passes in the created `<T: singleton>` type as input.

### iii. Notes on second implementation

Below are some additional thoughts on this implementation:
 1. This implementation exactly reverses the `init` constraint it sets out to alleviate: as `init` functions cannot have input arguments outside of OTWs and `TxContext`, the `SingletonRegistry` can't be passed in as input to allow calling the `register` function. This is an important trade-off and produces an equally, if not more, restrictive constraint on when `singleton` objects can be created.
 1. The `SingletonRegistry` is a `singleton` object itself. It cannot be be passed in as both arguments to `register`, thus its registering needs to be handled separately. The `verify_module` function needs to be aware of this and allow the `SingletonRegistry` to be created without a consecutive call to `register`.
 1. Using this approach, you could enable the deletion of `singleton` structs, to then allow for a later recreation of the `singleton`, by enforcing a call to a `deregister` function. I have not thought about the practicality of this but this is an additional feature not present in **Reference Implementation**.

## Security Considerations

This SIP does not introduce any *new* types of security concerns, however, when adding any feature or change to the Move language and the bytecode verifier proper precaution should be taken. The `singleton` ability **must** maintain the set of invariants outlined in **Specification**. As such, the new `verify_module` function should be thoroughly reviewed, tested, and audited to ensure the correctness of the `singleton` abilities invariants.

## References

1. [[Sui Repo] mainnet-v1.42.2](https://github.com/MystenLabs/sui/tree/mainnet-v1.42.2)
1. [[Aftermath Sui Repo] sip/singleton-ability](https://github.com/AftermathFinance/sui-public/tree/sip/singleton-ability)
1. [[Move Book] Abilities Introduction](https://move-book.com/move-basics/abilities-introduction.html?highlight=abilities#what-are-abilities)
1. [[Move Reference] Abilities](https://move-book.com/reference/abilities.html)
1. [[Move Book] One-Time Witness](https://move-book.com/programmability/one-time-witness.html?highlight=one#one-time-witness)
1. [[Sui Repo] One-Time Witness Verifier](https://github.com/MystenLabs/sui/blob/mainnet-v1.42.2/sui-execution/latest/sui-verifier/src/one_time_witness_verifier.rs)

## Copyright

[CC0 1.0](../LICENSE.md).
