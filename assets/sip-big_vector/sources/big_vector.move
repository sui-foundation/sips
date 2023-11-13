// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module typus_framework::big_vector {
    use std::vector;

    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;
    use sui::dynamic_field;

    // ======== Errors ========

    const E_NOT_EMPTY: u64 = 0;

    // ======== Structs ========

    struct BigVector<phantom Element> has key, store {
        id: UID,
        slice_count: u64,
        slice_size: u64,
        length: u64,
    }

    // ======== Functions ========

    /// create BigVector
    public fun new<Element: store>(slice_size: u64, ctx: &mut TxContext): BigVector<Element> {
        let id = object::new(ctx);
        let slice_count = 1;
        dynamic_field::add(&mut id, slice_count, vector::empty<Element>());
        BigVector<Element> {
            id,
            slice_count,
            slice_size,
            length: 0,
        }
    }

    /// return the slice_count of the BigVector
    public fun slice_count<Element: store>(bv: &BigVector<Element>): u64 {
        bv.slice_count
    }

    /// return the max size of a slice in the BigVector
    public fun slice_size<Element: store>(bv: &BigVector<Element>): u64 {
        bv.slice_size
    }

    /// return the size of the BigVector
    public fun length<Element: store>(bv: &BigVector<Element>): u64 {
        bv.length
    }

    /// return the slice_id related to the index i
    public fun slice_id<Element: store>(bv: &BigVector<Element>, i: u64): u64 {
        (i / bv.slice_size) + 1
    }

    /// return true if the BigVector is empty
    public fun is_empty<Element: store>(bv: &BigVector<Element>): bool {
        bv.length == 0
    }

    /// push a new element at the end of the BigVector
    public fun push_back<Element: store>(bv: &mut BigVector<Element>, element: Element) {
        if (length(bv) / bv.slice_size == bv.slice_count) {
            bv.slice_count = bv.slice_count + 1;
            let new_slice = vector::singleton(element);
            dynamic_field::add(&mut bv.id, bv.slice_count, new_slice);
        }
        else {
            let slice = dynamic_field::borrow_mut(&mut bv.id, bv.slice_count);
            vector::push_back(slice, element);
        };
        bv.length = bv.length + 1;
    }

    /// pop an element from the end of the BigVector
    public fun pop_back<Element: store>(bv: &mut BigVector<Element>): Element {
        let slice = dynamic_field::borrow_mut(&mut bv.id, bv.slice_count);
        let element = vector::pop_back(slice);
        trim_slice(bv);
        bv.length = bv.length - 1;

        element
    }

    /// borrow an element at index i from the BigVector
    public fun borrow<Element: store>(bv: &BigVector<Element>, i: u64): &Element {
        let slice_count = (i / bv.slice_size) + 1;
        let slice = dynamic_field::borrow(&bv.id, slice_count);
        vector::borrow(slice, i % bv.slice_size)
    }

    /// borrow a mutable element at index i from the BigVector
    public fun borrow_mut<Element: store>(bv: &mut BigVector<Element>, i: u64): &mut Element {
        let slice_count = (i / bv.slice_size) + 1;
        let slice = dynamic_field::borrow_mut(&mut bv.id, slice_count);
        vector::borrow_mut(slice, i % bv.slice_size)
    }

    /// borrow a slice from the BigVector
    public fun borrow_slice<Element: store>(bv: &BigVector<Element>, slice_count: u64): &vector<Element> {
        dynamic_field::borrow(&bv.id, slice_count)
    }

    /// borrow a mutable slice from the BigVector
    public fun borrow_slice_mut<Element: store>(bv: &mut BigVector<Element>, slice_count: u64): &mut vector<Element> {
        dynamic_field::borrow_mut(&mut bv.id, slice_count)
    }

    /// swap and pop the element at index i with the last element
    public fun swap_remove<Element: store>(bv: &mut BigVector<Element>, i: u64): Element {
        let result = pop_back(bv);
        if (i == length(bv)) {
            result
        } else {
            let slice_count = (i / bv.slice_size) + 1;
            let slice = dynamic_field::borrow_mut<u64, vector<Element>>(&mut bv.id, slice_count);
            vector::push_back(slice, result);
            vector::swap_remove(slice, i % bv.slice_size)
        }
    }

    /// remove the element at index i and shift the rest elements
    /// abort when reference more thant 1000 slices
    /// costly function, use wisely
    public fun remove<Element: store>(bv: &mut BigVector<Element>, i: u64): Element {
        let slice = dynamic_field::borrow_mut<u64, vector<Element>>(&mut bv.id, (i / bv.slice_size) + 1);
        let result = vector::remove(slice, i % bv.slice_size);
        let slice_count = bv.slice_count;
        while (slice_count > (i / bv.slice_size) + 1 && slice_count > 1) {
            let slice = dynamic_field::borrow_mut<u64, vector<Element>>(&mut bv.id, slice_count);
            let tmp = vector::remove(slice, 0);
            let prev_slice = dynamic_field::borrow_mut<u64, vector<Element>>(&mut bv.id, slice_count - 1);
            vector::push_back(prev_slice, tmp);
            slice_count = slice_count - 1;
        };
        trim_slice(bv);
        bv.length = bv.length - 1;

        result
    }

    /// drop BigVector, abort if it's not empty
    public fun destroy_empty<Element: store>(bv: BigVector<Element>) {
        let BigVector {
            id,
            slice_count: _,
            slice_size: _,
            length,
        } = bv;
        assert!(length == 0, E_NOT_EMPTY);
        let empty_slice = dynamic_field::remove(&mut id, 1);
        vector::destroy_empty<Element>(empty_slice);
        object::delete(id);
    }

    /// drop BigVector if element has drop ability
    /// abort when the BigVector contains more thant 1000 slices
    public fun drop<Element: store + drop>(bv: BigVector<Element>) {
        let BigVector {
            id,
            slice_count,
            slice_size: _,
            length: _,
        } = bv;
        while (slice_count > 0) {
            dynamic_field::remove<u64, vector<Element>>(&mut id, slice_count);
            slice_count = slice_count - 1;
        };
        object::delete(id);
    }

    /// remove empty slice after element removal
    fun trim_slice<Element: store>(bv: &mut BigVector<Element>) {
        let slice = dynamic_field::borrow_mut<u64, vector<Element>>(&mut bv.id, bv.slice_count);
        if (bv.slice_count > 1 && vector::length(slice) == 0) {
            let empty_slice = dynamic_field::remove(&mut bv.id, bv.slice_count);
            vector::destroy_empty<Element>(empty_slice);
            bv.slice_count = bv.slice_count - 1;
        };
    }
}

#[test_only]
module typus_framework::test_big_vector {
    use std::vector;

    use sui::test_scenario;

    use typus_framework::big_vector;

    #[test]
    fun test_big_vector_push_pop() {
        let scenario = test_scenario::begin(@0xAAAA);

        let tmp = 10;
        let big_vector = big_vector::new<u64>(3, test_scenario::ctx(&mut scenario));
        let count = 1;
        while (count <= tmp) {
            big_vector::push_back(&mut big_vector, count);
            count = count + 1;
        };
        // [1, 2, 3], [4, 5, 6], [7, 8, 9], [10]
        let slice_count_records = vector::empty();
        let value_history = vector::empty();
        let count = tmp;
        while (count > 0) {
            let slice_count = big_vector::slice_count(&big_vector);
            vector::push_back(&mut slice_count_records, slice_count);
            // std::debug::print(&slice_count);
            let value = big_vector::pop_back(&mut big_vector);
            vector::push_back(&mut value_history, value);
            // std::debug::print(&value);
            count = count - 1;
        };
        assert!(vector[4, 3, 3, 3, 2, 2, 2, 1, 1, 1] == slice_count_records, 0);
        assert!(vector[10, 9, 8, 7, 6, 5, 4, 3, 2, 1] == value_history, 0);

        big_vector::destroy_empty(big_vector);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_big_vector_swap_remove() {
        let scenario = test_scenario::begin(@0xAAAA);

        let tmp = 10;
        let big_vector = big_vector::new<u64>(3, test_scenario::ctx(&mut scenario));
        let count = 1;
        while (count <= tmp) {
            big_vector::push_back(&mut big_vector, count);
            count = count + 1;
        };
        // [1, 2, 3], [4, 5, 6], [7, 8, 9], [10]
        big_vector::swap_remove(&mut big_vector, 5);
        // [1, 2, 3], [4, 5, 10], [7, 8, 9]
        assert!(big_vector::slice_count(&big_vector) == 3, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 9, 0);
        assert!(big_vector::slice_count(&big_vector) == 3, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 8, 0);
        assert!(big_vector::slice_count(&big_vector) == 3, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 7, 0);
        assert!(big_vector::slice_count(&big_vector) == 2, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 10, 0);
        assert!(big_vector::slice_count(&big_vector) == 2, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 5, 0);
        assert!(big_vector::slice_count(&big_vector) == 2, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 4, 0);
        assert!(big_vector::slice_count(&big_vector) == 1, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 3, 0);
        assert!(big_vector::slice_count(&big_vector) == 1, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 2, 0);
        assert!(big_vector::slice_count(&big_vector) == 1, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 1, 0);

        big_vector::destroy_empty(big_vector);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_big_vector_remove() {
        let scenario = test_scenario::begin(@0xAAAA);

        let tmp = 10;
        let big_vector = big_vector::new<u64>(3, test_scenario::ctx(&mut scenario));
        let count = 1;
        while (count <= tmp) {
            big_vector::push_back(&mut big_vector, count);
            count = count + 1;
        };
        // [1, 2, 3], [4, 5, 6], [7, 8, 9], [10]
        big_vector::remove(&mut big_vector, 5);
        // [1, 2, 3], [4, 5, 7], [8, 9, 10]
        assert!(big_vector::slice_count(&big_vector) == 3, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 10, 0);
        assert!(big_vector::slice_count(&big_vector) == 3, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 9, 0);
        assert!(big_vector::slice_count(&big_vector) == 3, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 8, 0);
        assert!(big_vector::slice_count(&big_vector) == 2, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 7, 0);
        assert!(big_vector::slice_count(&big_vector) == 2, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 5, 0);
        assert!(big_vector::slice_count(&big_vector) == 2, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 4, 0);
        assert!(big_vector::slice_count(&big_vector) == 1, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 3, 0);
        assert!(big_vector::slice_count(&big_vector) == 1, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 2, 0);
        assert!(big_vector::slice_count(&big_vector) == 1, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 1, 0);

        big_vector::destroy_empty(big_vector);
        test_scenario::end(scenario);
    }

    #[test]
    /// since dynamic_field::borrow is costly, iteration with borrow/borrow_mut is also costly
    /// borrow each slice once and iterate the vector reduces the massive dynamic_field::borrow function
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
}