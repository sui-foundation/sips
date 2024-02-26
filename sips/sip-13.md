|   SIP-Number |  13                                                                                         |
| -----------: | :------------------------------------------------------------------------------------------ |
|        Title | BigVector Implementation                                                                    |
|  Description | Implementing BigVector to the Sui framework, using dynamic_fields to store multiple vectors |
|       Author | Jeric <@jericlong>, Wayne <@WayneAl>, Alvin <@alvin7878>                                    |
|       Editor | Amogh Gupta <amogh@sui.io, @amogh-sui>                                            |  
|         Type | Standard                                                                                    |
|     Category | Framework                                                                                   |
|      Created | 2023-11-09                                                                                  |
| Comments-URI | https://sips.sui.io/comments-13                                                             |
|       Status | Stagnant                                                                                       |
|     Requires | N/A                                                                                         |

## Abstract

This SIP specifies implementing BigVector to the Sui framework as an alternative data structure. The existing data structure implemented through dynamic_fields and vectors face object access and byte limitations within a single transaction. This inevitably leads to restrictions on scalability and risks associated with complex code.

This SIP builds on top of Sui’s dynamic_fields and vectors, offering a more efficient and cost-effective solution to memory allocation.

## Motivation

Without BigVector, projects that require heavy data access are required to split their operations into batches of transactions once they’ve reached dynamic_fields’ maximum access of 1,000 objects.

**Scalability.** This causes noticeable impact on execution speed, causing significant slowdown and increased gas fees.

In order to build truly scalable applications, gas fees should not increase with each dynamic_field access, and there should be a more efficient method for memory allocation.

**Security.** Even if gas fees weren’t a concern, splitting transactions introduces additional dependencies, increases chances of calculation discrepancies, and diminishes the overall robustness of the code.

This is a risk for time-sensitive applications that require single transaction operations. In previously observed cases, this can also lead to the loss of user funds.

To implement highly-scalable applications, a framework for consolidating the operation into one transaction while keeping gas fees at a minimum is needed.


## Specification

BigVector data structure stores and chains vectors(slices) with dynamic_fields. BigVector contains a `UID` to store the dynamic_field and uses `slice_count` as the key of each slice. Since the max size of a single object is 256000 bytes, BigVector sets a `slice_size` in order to limit the amount of elements inside a single slice.

BigVector provides similar functions as traditional vector, which contains `borrow`, `borrow_mut`, `length`, `is_empty`, `push_back`, `pop_back`, `swap_remove`, `remove`, `destroy_empty`.

Since gas fees for dynamic_field accesses are charged by the number of function calls, BigVector provides `borrow_slice` and `borrow_slice_mut` functions to access a single slice instead of accessing massive elements directly from `borrow` or `borrow_mut` functions.

## Rationale

With the 256,000 bytes limit of vectors and 1,000 objects access limit of dynamic_fields, BigVector is designed to address both these limitations simultaneously.

BigVector employs dynamic_fields to store multiple vectors, similar to breaking a large vector into many smaller slices.

This shatters the upper limit imposed by vectors by merging dynamic_fields and vectors, while simultaneously relaxing the access limitation of 1,000 objects within a dynamic_field.

This results in an increase in the number of elements that can be accessed within a single transaction, effectively enhancing scalability.

## Backwards Compatibility

This SIP presents no issues with backwards compatibility.

## Test Cases

## Reference Implementation

### BigVector iteration
Since gas fees for dynamic_field accesses are charged by the number of function calls, iteration with borrow/borrow_mut is also costly. The most efficient way is using `borrow_slice` or `borrow_slice_mut` function to get slices and iterate the vectors. If there are n slices and the slice_size is m, you may need n * m times of dynamic_field accesses with the traditional `borrow` or `borrow_mut`, but only n times with the `borrow_slice` or `borrow_slice_mut` function.

```Rust
fun test_big_vector_iteration() {
    let scenario = test_scenario::begin(@0xAAAA);

    let tmp = 5;
    let big_vector = big_vector::new<u64>(3, test_scenario::ctx(&mut scenario));
    let count = 1;
    while (count <= tmp) {
        big_vector::push_back(&mut big_vector, count);
        count = count + 1;
    };

    let result = vector::empty();
    // get BigVector settings
    let length = big_vector::length(&big_vector);
    let slice_size = big_vector::slice_size(&big_vector);
    let slice = big_vector::borrow_slice(&big_vector, 1);
    let i = 0;
    while (i < length) {
        // get element from slice
        let value = vector::borrow(slice, i % slice_size);
        vector::push_back(&mut result, *value);
        // jump to next slice
        if (i + 1 < length && (i + 1) % slice_size == 0) {
            let slice_id = big_vector::slice_id(&big_vector, i + 1);
            slice = big_vector::borrow_slice(
                &big_vector,
                slice_id,
            );
        };
        i = i + 1;
    };

    assert!(vector[1, 2, 3, 4, 5] == result, 0);

    big_vector::drop(big_vector);
    test_scenario::end(scenario);
}
```

## Security Considerations

None

## Copyright

[CC0 1.0.](https://github.com/sui-foundation/sips/blob/main/LICENSE.md)
