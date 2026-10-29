|   SIP-Number | 55 |
|         ---: | :--- |
|        Title | Infallible PTBs |
|  Description | Introduces infallible Programmable Transaction Blocks (PTBs) that enable partial state reversion and alternative execution paths when encountering aborts, allowing independent operations within a PTB to succeed even if others fail |
|       Author | Kevin \<github@aftermath.finance, @admin-aftermath\>, Aftermath Finance \<[aftermath.finance](https://aftermath.finance/)\> |
|       Editor | TBD |
|         Type | Standard |
|     Category | Framework |
|      Created | 2024-02-28 |
| Comments-URI | TBD |
|       Status | Draft |
|     Requires | N/A |

## Abstract

This SIP proposes infallible Programmable Transaction Blocks (PTBs) to Move. Infallible PTBs enable partial state reversion and [optionally] fallback execution paths when an abort is encountered, allowing independent operations within a PTB to succeed even if others fail.

This is particularly impactful for complex transaction flows where multiple independent operations are bundled together. Rather than having the entire PTB fail when a single operation aborts, infallible PTBs allow developers to specify fallback behaviors to lead to partial success states. Ultimately, this enables the creation of more robust and user-friendly Sui-based applications.

## Scope

This SIP defines the problem set that infallible PTBs aim to address and overviews four implementations of the feature. The SIP purposefully does not provide an *exact* implementation rather it aims to initiate a community discussion, where we can collaboratively explore the proposed designs and converge on the design that best serves the needs of both developers and users.

## Background

**Programmable Transaction Blocks.** Programmable Transaction Blocks (PTBs) are a core feature of Sui that enable the bundling of multiple operations into a singular atomic transaction; i.e., all operations either collectively succeed or the transaction fails.<sup>[1](https://docs.sui.io/concepts/transactions/prog-txn-blocks)</sup> This design encourages functions in Sui smart contracts to remain *relatively* simple, typically following the single-responsibility principle, and allows complex logic to be achieved by chaining together a series of these simpler functions.

If you are non-technical, first off - welcome to Sui's SIP repository, I will use a previous description of mine that details PTBs in a more friendly manner:<sup>[2](https://medium.com/@kevin-aftermath/aftermath-dollar-cost-averaging-5b2a08f0cdd6)</sup>
> Imagine you need to visit n grocery stores to buy everything on your list. Without the benefits of PTBs, you would have to visit one grocery store, load up your groceries, and drive straight home. Once you’ve unloaded your groceries, you can now visit the second store on your list. You would rinse and repeat this process until you’ve completed your entire list. Clearly, this wastes a lot of time and gas (both in this example and when applied to on-chain transactions). Instead, a PTB-enabled flow would allow you to visit the first store on your list, then the second, then the third, and continue until you either have visited all n stores on your list or hit the capacity of groceries you can fit in your car.

This analogy is great at highlighting the core benefit of PTBs but overlooks an important feature: the ability to chain the output of one function as input to a following function. In the grocery store example, this would be akin to using your credit card to withdraw cash at the first store to use as payment for groceries at a consecutive store that *only* accepts cash. The contrast to this is a formal restriction that you must use cash that you brought from your house and, if you did not previously have a sufficient amount of cash lying around, you would have had to go to the bank or an atm first to withdraw cash ***and*** return home before beginning your grocery shopping.

&nbsp;&nbsp;&nbsp;&nbsp; This feature means that the success of a function within a PTB can be dependent on the exact output of a previous function.

## Glossary

The below terms will come up throughout the remainder of this SIP:
 * **Entry Functions.** Before the time of PTBs, Move used the `entry` keyword to define the set of functions that were accessible to be called from off-chain.<sup>[3](https://move-book.com/reference/functions.html?highlight=entry#entry-modifier)</sup> PTBs completely revolutionized how you could interact with Sui smart contracts, for numerous reasons, but importantly with PTBs came the ability to call *any* `public` function from offchain. The `entry` keyword still exists syntactically, although its use has dwindled. There are a few caveats of `entry` functions that are worth looking into, but the only one relevant for this SIP is: `entry` functions cannot accept input that has been used by non-`entry` functions *during* the PTB.

 * **Sponsored Transactions.** Sponsored transactions are a feature of Sui that allow a third-party to pay for the gas associated with a transaction.<sup>[4](https://docs.sui.io/concepts/transactions/sponsored-transactions)</sup> This is particularly useful when a user wants to interact with a dApp but doesn't have the necessary SUI to pay for the gas, introducing a new vertical for dApps to onboard users.

## Motivation

**Limitations.** With PTBs, you can pack multiple disjoint actions into a single transaction, with the caveat that if one of these actions fails the entire PTB fails and ***all*** state is reverted. This can be a significant limitation when building complex systems that:
&nbsp;&nbsp;&nbsp;   i. Bundle context-dependent but outcome-independent actions into one transaction; e.g., a protocol that updates multiple oracle price feeds and performs consecutive actions utilizing the updated price feeds. Currently, if one of the follow-up actions fails, all price updates are reverted - even though those price updates are still valid and useful for other users.

&nbsp;&nbsp;  ii. Can inherently define partial success states; e.g., a DEX aggregator executing a complex route comprising multiple independent sub-paths through various liquidity pools. If one sub-path encounters insufficient liquidity or high slippage, the other successful sub-paths should have the ability to be completed rather than having the entire trade fail. For instance, if splitting a 1000 USDC trade across 4 sub-paths of 250 USDC each, having 3 sub-paths succeed is preferable to a complete failure.

&nbsp; iii. **Require** an action to be performed regardless of the outcome of following commands in the PTB. This is very similar to (i) although there are strict requirements that an action must be performed; e.g., `advance_epoch` bundles together multiple system operations in order to crank the epoch advancement. Of these, there are certain actions that **must** be performed in order to enter the new epoch. If any of the operations fails, `advance_epoch` cannot be completed and instead `advance_epoch_safe_mode` is executed in order to execute the bare minimum crank.

To extend our running example: Imagine, while visiting the `mth` grocery store on your list, a clerk tells you that they are out of one of the items on your list. In the current system, you would have to leave the store without any of the groceries you picked up, return the groceries from all previous `m - 1` stores, head back home, and pay both in time and for the gas associated with driving to all stores. Instead, wouldn't it be great if you could purchase all available groceries from the `mth` store, keep the groceries from the previous `m - 1` stores, and continue working down your list? This is the problem infallible PTBs aim to solve.

**Workarounds.** Today, if you were required to implement one of the previous examples, you would have two general approaches to emulate partial success:
 1. Check execution logic on-chain before completing each action, using a variant of each function that returns success state and doesn't abort in the case of failures. This very obviously increases the gas cost associated with these actions and is not possible when working with third-party packages that don't provide the necessary functions (hint: no one does this as why should they?).
 1. Submit a soft bundle where each PTB in the bundle contains a minimal set of actions that need to be collectively reverted if a failure should occur. There are a few downsides with this approach, most notably:
    1. Less efficient than a single PTB in scenarios where you are touching the same state across a subset of the included PTBs.
    1. You are limited to the constraints of soft bundles, such as the maximum number of PTBs that can be bundled (`n = 5`), are forced to set the gas price across all included PTBs, and you cannot include PTBs that only touch owned object. For the last case, this can prevent you from ensuring a payment (likely a simple transfer) is made regardless of the outcome of other actions.
    1. Included PTBs cannot utilize the objects created in the PTBs that precede it.
    1. You are not guaranteed the ordering of the included PTBs.
&nbsp;&nbsp;&nbsp;&nbsp; If you were to attempt the same idea without soft bundles, you would be faced with a subset of these limitations as well as you have less assurance on the ordering of the PTBs and the number of other transactions between the PTBs.

It is clear that these workarounds are not practical replacements for this SIP.

**Infallible PTBs.** Infallible PTBs aim to address the above limitations by enabling partial state reversion and the use of fallback execution paths when encountering aborts. This allows independent operations within a PTB to succeed even if others fail, providing a more robust and user-friendly experience for both developers and users. Formalizing on the above examples, below is a non-exhaustive list of network participants and prominent domains that would greatly benefit from infallible PTBs.

&nbsp;&nbsp;&nbsp;&nbsp; **Aggregators.** The role of an aggregator is to aggregate many actions into one. Within DeFi there have been many verticals that have greatly benefited from the simple abstraction that an aggregator provides; for example, DEX, lending, or yield aggregators. Aggregators typically provide more efficient outcomes as their complexity increases -- this introduces a trade-off between the efficiency gained versus the risk of a failure as complexity increases. Infallible PTBs would allow for the creation of more complex aggregators that can specify fallback behaviors when one of the aggregated venues or actions fails.

&nbsp;&nbsp;&nbsp;&nbsp; **Market Makers.** I will generalize this category by labelling it as **Market Makers** but this section applies to any actor who benefits from bundling *many* actions into one transaction, likely to reduce gas costs. Market makers manage a portfolio of assets and do so by actively rebalancing their positions across an array of protocols, markets, etc. It is often cheaper to bundle these actions into one PTB rather than executing each action individually -- over long periods of time this reduction becomes significant. Market makers are then faced with the same trade-off of optimizing for efficiency versus the risk of a failure. Infallible PTBs would allow market makers to better manage their liquidity by enabling them to continue managing their portfolio even in the face of unexpected errors.

&nbsp;&nbsp;&nbsp;&nbsp; **MEV.** The difference between the previous two is that **Aggregators** typically involve multiple dependent actions while **Market Makers** typically involve multiple independent actions. Maximum extractable value (MEV), on the other hand, often requires a mixture of dependent and independent actions by composing actions across a plethora of on-chain venues in order to capture leaked value. In the case of arbitrage, you end up in a scenario akin to the one described in **Aggregators**. In the case of liquidations, you are likely faced with a trade-off similar to the one outlined in **Market Makers**. As described, infallible PTBs can help searchers capture more complex types of MEV opportunities that would otherwise be limited by the true atomicity present in today's PTBs.

&nbsp;&nbsp;&nbsp;&nbsp; **Sponsored Transactions.** While its true that sponsored transactions are an extremely impactful tool for onboarding users, they are typically limited in their dynamism as failures within the sponsored transaction still result in the sponsor paying for gas. This restricts dApps to utilize sponsored transactions to only support a limited subset of possible user actions: the set of actions the dApp understands and have whitelisted. For example, imagine a wallet wanting to run a promotion where they sponsor the first `n` transactions for all new users. In this scenario the wallet could easily be exploited, in an attempt to deplete their supply of SUI, by constructing purposefully failing transactions. Due to this limitation, sponsored transactions have difficulty in fully achieving their true desire of simple, *unbounded* user onboarding. Infallible PTBs would enable sponsored transactions to be more robust by allowing developers to specify fallback behaviors when a sponsored transaction fails.

&nbsp;&nbsp;&nbsp;&nbsp; **`advance_epoch`.** In the case that there is an error originating from within `advance_epoch`, the fall-back path (i.e., `advance_epoch_safe_mode`) is automatically performed. With infallible PTBs, you could represent this fallback-path more explicitly and / or split `advance_epoch` into multiple functions comprising the total `advance_epoch` functionality and whose execution statuses are now decoupled.

## Prerequisites

There are no prerequisites for this SIP.

## Specification

Programmable Transaction Blocks will be extended to support infallible transactions. Specifically infallible PTBs:
 1. Allow parts of a transaction to fail and be reverted without affecting the rest of the transaction.
 1. Allow specifying alternate, fallback execution paths for parts of a transaction that fails.

All touched objects, regardless of if they are actually interacted with, will be passed in as input to the PTB and locked or modified accordingly.

## Rationale

I hope by now the rationale is clear: infallible PTBs enable the creation of more robust Sui-based applications that can dynamically respond to failures that occur on-chain, likely caused by changes to on-chain state between the time the transaction is built and when it is executed. As a result, developers can build more complex systems that can handle unexpected errors more gracefully, leading to an overall better user experience and a more interesting set of applications that can be built on Sui.

## Backwards Compatibility

This SIP presents no issues with backwards compatibility.

## Reference Implementation

Below I outline four possible designs for the above specification. For each reference implementation I provide a brief description of the implementation and mention a list of benefits and limitations inherent to the design.

### i. `try-catch` within Move

#### ia. Design

The most direct way to implement infallible PTBs is to introduce a `try-catch` statement within Move. The `try-catch` statement would be used to wrap the code that should be revertible and the fallback code that should be executed if the `try` code fails. Here is an example of what the syntax would look like:
```Move
public fun swap<CoinIn, CoinOut>(
    pool: &mut Pool,
    coin_in: Coin<CoinIn>,
): Coin<CoinOut> {
    let coin_out = try {
        pool.swap_inner(coin_in)
    } else {
        coin::zero<CoinOut>()
    };

    ...

    coin_out
}
```

This is a fairly invasive change, I will briefly describe the general changes required.

**Move Compiler.** The `try` and `catch` keywords would need to be added to Move. As such the Move AST and Move IR would need to be updated to understand these keywords.

**Move Bytecode.** The Move Bytecode would need to be updated to add `Bytecode::PushTry` and `Bytecode::PopTry`. `Bytecode::PushTry` would be used to push the current context of the `try-catch` statement and `Bytecode::PopTry` would be used to pop the latest `try-catch` statement context. I have picked the names `PushTry` and `PopTry` as `Try___` doesn't perfectly convey its meaning.

**Move Interpreter.** When a `try` statement is encountered, the Move interpreter would need to track the context for the `try-catch` statement, including (1) the pc of the `catch` statement, (2) a snapshot of all `Local` variables (in order to revert state in the face of an abort), and (3) the `Stack` depth size to allow unwinding the stack to the correct depth. When `Bytecode::PushTry` is encountered the interpreter would need to save the current `try-catch` context. The `Frame` struct will need to be updated to support tracking of `try-catch` contexts. When `Bytecode::PopTry` is encountered the interpreter would need to remove the top context from the `Frame`. The handling of `Bytecode::Abort` would need to be modified to check if the context is currently within a `try` block and if so (1) unwind the stack, (2) reset all `local` variables, and (3) jump to the `catch` block.

#### ib. Comments

**Benefits.**
 * This approach is the most direct way to implement infallible PTBs, as it allows developers to specify fallback behaviors for specific functions.
 * The `try-catch` statement is a common across many programming languages so it will be widely understood.
 * `try-catch` meets both requirements outlined in the specification.
 * `try-catch` is a useful construct for many use-cases outside of the context of this SIP.

**Limitations.**
 * This approach is less dynamic than the other approaches, as the fallback behavior needs to be hard-coded on-chain. If a third-party dependency does not wrap a function in a `try-catch` statement, you would need to wrap it yourself in a new package.
 * In many cases, one domain action is not equivalent to one function call. This means that the `try-catch` statement would need to be wrapped around multiple function calls, which could lead to a more complex implementation.

### ii. `try-catch` when constructing PTB

#### iia. Design

Allow specifying `try-catch` semantics when constructing a PTB off-chain. Requires modifications to the PTB builder to support wrapping sequences of commands in `try-catch` blocks.

**ProgrammableTansactionBuilder.** The `ProgrammableTransactionBuilder` would need to be updated to support wrapping sequences of commands in `try-catch` blocks. The calling syntax would look like:
```rust
let mut builder = ProgrammableTransactionBuilder::new();

...

builder.try(vec![
    Command::move_call(...),
    Command::move_call(...),
]).catch(vec![
    Command::move_call(...),
]);
```

&nbsp;&nbsp;&nbsp;&nbsp; The `.try(...).catch(...)` would be expanded into a Script<sup>[5](https://diem.github.io/move/modules-and-scripts.html)</sup> that contains one function (e.g., `main`) that wraps the provided `Command`s in a `try-catch` block. The `main` function would be called by the PTB directly.

&nbsp;&nbsp;&nbsp;&nbsp; This design provides a flexible way to handle failures without requiring Move language changes (from the users--developer--perspective), while maintaining the atomic properties of successful operations.

#### iib. Comments

**Benefits.**
 * Allows developers to specify fallback behaviors for specific functions entirely off-chain without needing to write and publish their own wrappers around specific functions.
 * Allows bundling multiple operations within `try-catch` statement, as opposed to a approach (i) where you are limited to wrapping one function within a `try` block.
 * Syntactically very simple to read, write, and understand.

**Limitations.**
 * The most invasive approach.
 * `try-catch` blocks are subject to the bounds set on individual function calls (i.e., `max_arguments`, `max_type_arguments`), since these blocks are expanded into a single function.
 * Requires a way to construct Move code off-chain and pass as input, such as with Diem scripts. This is a large ask that likely requires an SIP of its own.
 * Also requires adding `try-catch` on-chain.

### iii. Represent PTBs as bundles of series of commands

#### iiia. Design

Allow splitting a PTB into a series of groups of commands, where outcomes between groups become disjoint; i.e., if group `n` of a PTB fails, then group `n + 1` should still be given the chance to be executed. Commands from a group `n` could not take as input an argument that was the output of a command from group `m`; i.e., groups cannot be codependent on one another.

**ProgrammableTransactionBuilder.** The `ProgrammableTransactionBuilder` would need to be updated to support grouping commands together. The calling syntax would look like:
```rust
let mut builder = ProgrammableTransactionBuilder::new();

builder.group(|b| {
    b.move_call(...);
    b.move_call(...);
});

builder.group(|b| {
    b.move_call(...);
});
```

**Sui Execution.** The Sui execution engine would need to be updated to:
 1. Execute groups of commands and handle state reversion for failing groups.
 1. Aggregate transaction effects across all groups.
 1. Meter gas across all groups.

#### iiib. Comments

**Benefits.**
 * Less invasive than the previous two approaches, as it doesn't require changing the Move language itself or Diem scripts.
 * Natural fit for many real-world use cases.
 * Simpler to implement than other approaches as it builds on existing PTB infrastructure.

**Limitations.**
 * Less granular control compared to the previous two approaches, as you can't specify fallback behaviors for specific functions.
 * Must structure PTBs in a way that groups are disjoint.
 * Not being able to use the output of one group as input in another group could lead to a weird scenarios; e.g., an `n x m` route would produce at most `n` coins. These coins could not be joined together and would need to be transferred back to the sender individually.

### iv. `Result` type within Move

Allow specifying a `Result` type within Move that can be used to wrap the output of a function. If the function succeeds then a `Result::Ok` variant, that wraps the function's output, is returned. If the function fails, a `Result::Error` variant is returned that wraps the underlying abort code. This result type could then be used further up in the call stack to execute fallback behaviors in the case of a failure.

#### iva. Design

**Sui Framework.** The `Result` type would need to be added to the Sui Framework. Functions can then return this `Result<T>` type, where `T` is the underlying function output. The core implementation would consist of:

```Move
module sui::result;

public enum Result<Ok> {
    Ok(Ok),
    Error(u64),
}

// Allows re-aborting the wrapped abort code.
public fun abort<T>(result: Result<T>) {
    match result {
        Ok(_) => abort ENotError,
        Error(abort_code) => abort_inner(abort_code),
    }
}

native fun abort_inner<T>(result: Result<T>);

...

// Getters + unpacking function.
```

**Move Interpreter.** The Move interpreter would need to be updated to understand the `Result` type. When a function returns a `Result::Error` variant, the interpreter would need to check if the function is within a `try-catch` block and if so, execute the fallback behavior. The handling of `Bytecode::Abort` would need to be modified to check if the function is within a `try-catch` block and if so, execute

```Rust
Bytecode::Abort => {
    let error_code = interpreter.operand_stack.pop_as::<u64>()?;

    if function.should_wrap_abort() {
        gas_meter.charge_simple_instr(S::WrapAbort)?;

        let (field_count, variant_tag) = resolver.variant_field_count_and_tag(*vidx);
        let enum_type = resolver.get_enum_type(*vidx);

        Self::check_depth_of_type(resolver, &enum_type)?;
        gas_meter.charge_pack(
            false,
            interpreter.operand_stack.last_n(field_count as usize)?,
        )?;

        interpreter
            .operand_stack
            .push(Value::variant(Variant::pack(variant_tag, error_code)))?;

        interpreter.operand_stack.push(error)?;

        return Ok(InstrRet::ExitCode(ExitCode::Return));
    } else {
        gas_meter.charge_simple_instr(S::Abort)?;

        let error = PartialVMError::new(StatusCode::ABORTED)
            .with_sub_status(error_code)
            .with_message(format!("{} at offset {}", function.pretty_string(), *pc,));

        return Err(error);
    }
}
```

#### ivb. Comments

**Benefits.**
 * Similar benefits as listed by `try-catch`.
 * Allows you to support fallback scenarios for different abort codes.

**Limitations.**
 * Similar limitations as listed by `try-catch`.
 * This a big one: `Result` would require supplying a tuple as a generic, which currently isn't possible.
 * Similar limitations to `try-catch`: the fallback behavior needs to be hard-coded on-chain, requires manually wrapping functions if you want to allow reverting more than one function.
 * A function would need to return a `Result` or else you couldn't handle failures from the function, the previous approaches don't suffer from this constraint.

## Security Considerations

This SIP alters the true atomicity of Sui's PTBs to "partial atomicity" (a very contradictory term). As such, there are many factors to consider to maintain the integrity of state across transactions with varying execution paths. First and foremost, when a portion of a transaction is rolled back--in order to enter a fallback execution path--any state that was modified during the rolled-back commands should also be reverted. In other words: state reversion needs to remain true, as it exists today, for the portions of a transaction that fail.

***All*** Move runtime errors must be treated the same, whether it is a primitive runtime error (e.g., division by zero) or a module-defined abort. Otherwise, a malicious actor could exploit this feature by purposefully causing a primitive runtime error to avoid triggering an expected fallback behavior.

As with failing transactions today, the portions of a PTB that fail still need to be charges gas. This is to prevent malicious actors from creating transactions that purposefully perform complex / heavy move calls that are designed to fail and revert to a simple fallback path.

This SIP also introduces a very important question impacting user-experience: what output should wallets display for the outcome of transactions and, more generally, how should dry-runs be handled? The use of a fallback case is only determined at execution time. At the time the transaction is being dry-run by a wallet, in order to display transaction effects to an end user, the transaction could entirely succeed (i.e., bypass any fallback case). However, at the time of execution the transaction could only partially succeed and pass through the fallback execution paths. To make matters worse, there could be multiple fallback cases producing at most 2<sup>n</sup> possible execution paths.

## Conclusion

To reiterate, this SIP is designed to spark a conversation around the topic of infallible PTBs. The SIP proposes many different ways of achieving this design but of course there are other designs not mentioned. I will continue to update this SIP as the conversation develops.

## References

1. [[Sui Docs] Programmable Transaction Blocks](https://docs.sui.io/concepts/transactions/prog-txn-blocks)
2. [[Medium] Aftermath | Dollar Cost Averaging](https://medium.com/@kevin-aftermath/aftermath-dollar-cost-averaging-5b2a08f0cdd6)
3. [[Move Book] Functions](https://move-book.com/reference/functions.html?highlight=entry#entry-modifier)
4. [[Move Book] Functions](https://docs.sui.io/concepts/transactions/sponsored-transactions)
5. [[Diem Move Book] Modules and Scripts](https://diem.github.io/move/modules-and-scripts.html)

## Copyright

[CC0 1.0](../LICENSE.md).
