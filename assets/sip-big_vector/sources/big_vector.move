// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module typus_framework::big_vector {
    use std::vector;

    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;
    use sui::dynamic_field;

    // ======== Constants ========

    const CMaxSliceSize: u32 = 262144;

    // ======== Errors ========

    const ENotEmpty: u64 = 0;
    const EMaxSliceSize: u64 = 1;

    // ======== Structs ========

    struct BigVector<phantom Element> has key, store {
        id: UID,
        slice_idx: u64,
        slice_size: u32,
        length: u64,
    }

    // ======== Functions ========

    /// create BigVector
    public fun new<Element: store>(slice_size: u32, ctx: &mut TxContext): BigVector<Element> {
        assert!(slice_size <= CMaxSliceSize, EMaxSliceSize);

        let id = object::new(ctx);
        BigVector<Element> {
            id,
            slice_idx: 0,
            slice_size,
            length: 0,
        }
    }

    /// return the slice_idx of the BigVector
    public fun slice_idx<Element: store>(bv: &BigVector<Element>): u64 {
        bv.slice_idx
    }

    /// return the max size of a slice in the BigVector
    public fun slice_size<Element: store>(bv: &BigVector<Element>): u32 {
        bv.slice_size
    }

    /// return the size of the BigVector
    public fun length<Element: store>(bv: &BigVector<Element>): u64 {
        bv.length
    }

    /// return true if the BigVector is empty
    public fun is_empty<Element: store>(bv: &BigVector<Element>): bool {
        bv.length == 0
    }

    /// push a new element at the end of the BigVector
    public fun push_back<Element: store>(bv: &mut BigVector<Element>, element: Element) {
        if (is_empty(bv) || length(bv) % (bv.slice_size as u64) == 0) {
            bv.slice_idx = length(bv) / (bv.slice_size as u64);
            let new_slice = vector::singleton(element);
            dynamic_field::add(&mut bv.id, bv.slice_idx, new_slice);
        }
        else {
            let slice = dynamic_field::borrow_mut(&mut bv.id, bv.slice_idx);
            vector::push_back(slice, element);
        };
        bv.length = bv.length + 1;
    }

    /// pop an element from the end of the BigVector
    public fun pop_back<Element: store>(bv: &mut BigVector<Element>): Element {
        let slice = dynamic_field::borrow_mut(&mut bv.id, bv.slice_idx);
        let element = vector::pop_back(slice);
        trim_slice(bv);
        bv.length = bv.length - 1;

        element
    }

    /// borrow an element at index i from the BigVector
    public fun borrow<Element: store>(bv: &BigVector<Element>, i: u64): &Element {
        let slice_idx = (i / (bv.slice_size as u64)) + 1;
        let slice = dynamic_field::borrow(&bv.id, slice_idx);
        vector::borrow(slice, i % (bv.slice_size as u64))
    }

    /// borrow a mutable element at index i from the BigVector
    public fun borrow_mut<Element: store>(bv: &mut BigVector<Element>, i: u64): &mut Element {
        let slice_idx = (i / (bv.slice_size as u64)) + 1;
        let slice = dynamic_field::borrow_mut(&mut bv.id, slice_idx);
        vector::borrow_mut(slice, i % (bv.slice_size as u64))
    }

    /// borrow a slice from the BigVector
    public fun borrow_slice<Element: store>(bv: &BigVector<Element>, slice_idx: u64): &vector<Element> {
        dynamic_field::borrow(&bv.id, slice_idx)
    }

    /// borrow a mutable slice from the BigVector
    public fun borrow_slice_mut<Element: store>(bv: &mut BigVector<Element>, slice_idx: u64): &mut vector<Element> {
        dynamic_field::borrow_mut(&mut bv.id, slice_idx)
    }

    /// swap and pop the element at index i with the last element
    public fun swap_remove<Element: store>(bv: &mut BigVector<Element>, i: u64): Element {
        let result = pop_back(bv);
        if (i == length(bv)) {
            result
        } else {
            let slice_idx = i / (bv.slice_size as u64);
            let slice = dynamic_field::borrow_mut<u64, vector<Element>>(&mut bv.id, slice_idx);
            vector::push_back(slice, result);
            vector::swap_remove(slice, i % (bv.slice_size as u64))
        }
    }

    /// remove the element at index i and shift the rest elements
    /// abort when reference more thant 1000 slices
    /// costly function, use wisely
    public fun remove<Element: store>(bv: &mut BigVector<Element>, i: u64): Element {
        let slice = dynamic_field::borrow_mut<u64, vector<Element>>(&mut bv.id, (i / (bv.slice_size as u64)));
        let result = vector::remove(slice, i % (bv.slice_size as u64));
        let slice_idx = bv.slice_idx;
        while (slice_idx > i / (bv.slice_size as u64) && slice_idx > 0) {
            let slice = dynamic_field::borrow_mut<u64, vector<Element>>(&mut bv.id, slice_idx);
            let tmp = vector::remove(slice, 0);
            let prev_slice = dynamic_field::borrow_mut<u64, vector<Element>>(&mut bv.id, slice_idx - 1);
            vector::push_back(prev_slice, tmp);
            slice_idx = slice_idx - 1;
        };
        trim_slice(bv);
        bv.length = bv.length - 1;

        result
    }

    /// drop BigVector, abort if it's not empty
    public fun destroy_empty<Element: store>(bv: BigVector<Element>) {
        let BigVector {
            id,
            slice_idx: _,
            slice_size: _,
            length,
        } = bv;
        assert!(length == 0, ENotEmpty);
        object::delete(id);
    }

    /// drop BigVector if element has drop ability
    /// abort when the BigVector contains more thant 1000 slices
    public fun drop<Element: store + drop>(bv: BigVector<Element>) {
        let BigVector {
            id,
            slice_idx,
            slice_size: _,
            length: _,
        } = bv;
        while (slice_idx > 0) {
            dynamic_field::remove<u64, vector<Element>>(&mut id, slice_idx);
            slice_idx = slice_idx - 1;
        };
        dynamic_field::remove<u64, vector<Element>>(&mut id, slice_idx);
        object::delete(id);
    }

    /// remove empty slice after element removal
    fun trim_slice<Element: store>(bv: &mut BigVector<Element>) {
        let slice = dynamic_field::borrow_mut<u64, vector<Element>>(&mut bv.id, bv.slice_idx);
        if (bv.slice_idx > 0 && vector::is_empty(slice)) {
            let empty_slice = dynamic_field::remove(&mut bv.id, bv.slice_idx);
            vector::destroy_empty<Element>(empty_slice);
            bv.slice_idx = bv.slice_idx - 1;
        };
    }
}

#[test_only]
module typus_framework::test_big_vector {
    use std::vector;

    use sui::test_scenario;

    use typus_framework::big_vector::{Self, BigVector};

    #[test]
    fun test_big_vector_push_pop() {
        let scenario = test_scenario::begin(@0xAAAA);
        let big_vector = big_vector::new<u64>(2, test_scenario::ctx(&mut scenario));

        let count = 0;
        while (count < 5) {
            big_vector::push_back(&mut big_vector, count + 1);
            count = count + 1;
        };
        // [1, 2], [3, 4], [5]
        assert_result(
            &big_vector,
            vector[
                vector[0, 1],
                vector[0, 2],
                vector[1, 3],
                vector[1, 4],
                vector[2, 5],
            ],
        );
        let count = 0;
        while (count < 2) {
            big_vector::pop_back(&mut big_vector);
            count = count + 1;
        };
        // [1, 2], [3]
        assert_result(
            &big_vector,
            vector[
                vector[0, 1],
                vector[0, 2],
                vector[1, 3],
            ],
        );

        big_vector::drop(big_vector);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_big_vector_swap_remove() {
        let scenario = test_scenario::begin(@0xAAAA);
        let big_vector = big_vector::new<u64>(2, test_scenario::ctx(&mut scenario));

        let count = 0;
        while (count < 5) {
            big_vector::push_back(&mut big_vector, count + 1);
            count = count + 1;
        };
        // [1, 2], [3, 4], [5]
        assert_result(
            &big_vector,
            vector[
                vector[0, 1],
                vector[0, 2],
                vector[1, 3],
                vector[1, 4],
                vector[2, 5],
            ],
        );
        big_vector::swap_remove(&mut big_vector, 2);
        // [1, 2], [5, 4]
        assert_result(
            &big_vector,
            vector[
                vector[0, 1],
                vector[0, 2],
                vector[1, 5],
                vector[1, 4],
            ],
        );

        big_vector::drop(big_vector);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_big_vector_remove() {
        let scenario = test_scenario::begin(@0xAAAA);

        let big_vector = big_vector::new<u64>(2, test_scenario::ctx(&mut scenario));
        let count = 0;
        while (count < 5) {
            big_vector::push_back(&mut big_vector, count + 1);
            count = count + 1;
        };
        // [1, 2], [3, 4], [5]
        assert_result(
            &big_vector,
            vector[
                vector[0, 1],
                vector[0, 2],
                vector[1, 3],
                vector[1, 4],
                vector[2, 5],
            ],
        );
        big_vector::remove(&mut big_vector, 2);
        // [1, 2], [4, 5]
        assert_result(
            &big_vector,
            vector[
                vector[0, 1],
                vector[0, 2],
                vector[1, 4],
                vector[1, 5],
            ],
        );
        big_vector::remove(&mut big_vector, 0);
        // [2, 4], [5]
        assert_result(
            &big_vector,
            vector[
                vector[0, 2],
                vector[0, 4],
                vector[1, 5],
            ],
        );
        big_vector::remove(&mut big_vector, 1);
        // [2, 5]
        assert_result(
            &big_vector,
            vector[
                vector[0, 2],
                vector[0, 5],
            ],
        );

        big_vector::drop(big_vector);
        test_scenario::end(scenario);
    }

    #[test]
    /// since dynamic_field::borrow is costly, iteration with borrow/borrow_mut is also costly
    /// borrow each slice once and iterate the vector reduces the massive dynamic_field::borrow function
    fun test_big_vector_iteration() {
        let scenario = test_scenario::begin(@0xAAAA);

        let big_vector = big_vector::new<u64>(2, test_scenario::ctx(&mut scenario));
        let count = 0;
        while (count < 5) {
            big_vector::push_back(&mut big_vector, count + 1);
            count = count + 1;
        };

        // [1, 2], [3, 4], [5]
        assert_result(
            &big_vector,
            vector[
                vector[0, 1],
                vector[0, 2],
                vector[1, 3],
                vector[1, 4],
                vector[2, 5],
            ],
        );

        big_vector::drop(big_vector);
        test_scenario::end(scenario);
    }

    fun assert_result(
        big_vector: &BigVector<u64>,
        expected_result: vector<vector<u64>>,
    ) {
        // let current_slice_idx = big_vector::slice_idx(big_vector);
        // let slice_idx = 0;
        // while (slice_idx <= current_slice_idx) {
        //     std::debug::print(big_vector::borrow_slice(big_vector, slice_idx));
        //     slice_idx = slice_idx + 1;
        // };
        let result = vector::empty();
        let length = big_vector::length(big_vector);
        let slice_size = (big_vector::slice_size(big_vector) as u64);
        let slice_idx = 0;
        let slice = big_vector::borrow_slice(big_vector, slice_idx);
        let i = 0;
        while (i < length) {
            vector::push_back(
                &mut result,
                vector[slice_idx, *vector::borrow(slice, i % slice_size)],
            );
            // std::debug::print(value);
            // jump to next slice
            if (i + 1 < length && (i + 1) % slice_size == 0) {
                slice_idx = (i + 1) / (slice_size as u64);
                slice = big_vector::borrow_slice(
                    big_vector,
                    slice_idx,
                );
            };
            i = i + 1;
        };
        assert!(expected_result == result, 0);
    }
}