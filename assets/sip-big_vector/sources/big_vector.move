// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module typus_framework::big_vector {
    use std::vector;
    use std::type_name::{Self, TypeName};

    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;
    use sui::dynamic_field;

    // ======== Constants ========

    const CMaxSliceSize: u32 = 262144;

    // ======== Errors ========

    const EInvalidSliceSize: u64 = 0;
    const ENotEmpty: u64 = 1;
    const EIsEmpty: u64 = 2;
    const EIndexOutOfBounds: u64 = 3;

    // ======== Structs ========

    struct BigVector has key, store {
        /// the ID of the BigVector
        id: UID,
        /// the element type of the BigVector
        element_type: TypeName,
        /// the latest index of the Slice in the BigVector
        slice_idx: u64,
        /// the max size of each Slice in the BigVector
        slice_size: u32,
        /// the length of the BigVector
        length: u64,
    }

    struct Slice<Element> has store, drop {
        /// the index of the Slice
        idx: u64,
        /// the vector which stores elements
        vector: vector<Element>,
    }

    // ======== Functions ========

    /// create BigVector
    public fun new<Element: store>(slice_size: u32, ctx: &mut TxContext): BigVector {
        // slice_size * sizeof(Element) should be below the object size limit 256000 bytes.
        assert!(slice_size > 0 && slice_size <= CMaxSliceSize, EInvalidSliceSize);

        BigVector {
            id: object::new(ctx),
            element_type: type_name::get<Element>(),
            slice_idx: 0,
            slice_size,
            length: 0,
        }
    }

    /// return the latest index of the Slice in the BigVector
    public fun slice_idx(bv: &BigVector): u64 {
        bv.slice_idx
    }

    /// return the max size of each Slice in the BigVector
    public fun slice_size(bv: &BigVector): u32 {
        bv.slice_size
    }

    /// return the length of the BigVector
    public fun length(bv: &BigVector): u64 {
        bv.length
    }

    /// return true if the BigVector is empty
    public fun is_empty(bv: &BigVector): bool {
        bv.length == 0
    }

    /// return the index of the Slice
    public fun get_slice_idx<Element>(slice: &Slice<Element>): u64 {
        slice.idx
    }

    /// return the length of the element in the Slice
    public fun get_slice_length<Element>(slice: &Slice<Element>): u64 {
        vector::length(&slice.vector)
    }

    /// push a new element at the end of the BigVector
    public fun push_back<Element: store>(bv: &mut BigVector, element: Element) {
        if (is_empty(bv) || length(bv) % (bv.slice_size as u64) == 0) {
            bv.slice_idx = length(bv) / (bv.slice_size as u64);
            let new_slice = Slice {
                idx: bv.slice_idx,
                vector: vector::singleton(element)
            };
            dynamic_field::add(&mut bv.id, bv.slice_idx, new_slice);
        }
        else {
            let slice = borrow_slice_mut_(&mut bv.id, bv.slice_idx);
            vector::push_back(&mut slice.vector, element);
        };
        bv.length = bv.length + 1;
    }

    /// pop an element from the end of the BigVector
    public fun pop_back<Element: store>(bv: &mut BigVector): Element {
        assert!(!is_empty(bv), EIsEmpty);

        let slice = borrow_slice_mut_(&mut bv.id, bv.slice_idx);
        let element = vector::pop_back(&mut slice.vector);
        trim_slice<Element>(bv);
        bv.length = bv.length - 1;

        element
    }

    /// borrow an element at index i from the BigVector
    public fun borrow<Element: store>(bv: &BigVector, i: u64): &Element {
        assert!(i < bv.length, EIndexOutOfBounds);
        assert!(!is_empty(bv), EIsEmpty);

        let slice = borrow_slice_(&bv.id, i / (bv.slice_size as u64));
        vector::borrow(&slice.vector, i % (bv.slice_size as u64))
    }

    /// borrow a mutable element at index i from the BigVector
    public fun borrow_mut<Element: store>(bv: &mut BigVector, i: u64): &mut Element {
        assert!(i < bv.length, EIndexOutOfBounds);
        assert!(!is_empty(bv), EIsEmpty);

        let slice = borrow_slice_mut_(&mut bv.id, i / (bv.slice_size as u64));
        vector::borrow_mut(&mut slice.vector, i % (bv.slice_size as u64))
    }

    /// borrow a slice from the BigVector
    public fun borrow_slice<Element: store>(bv: &BigVector, slice_idx: u64): &Slice<Element> {
        assert!(slice_idx <= bv.slice_idx, EIndexOutOfBounds);
        assert!(!is_empty(bv), EIsEmpty);

        borrow_slice_(&bv.id, slice_idx)
    }
    fun borrow_slice_<Element: store>(id: &UID, slice_idx: u64): &Slice<Element> {
        dynamic_field::borrow(id, slice_idx)
    }

    /// borrow a mutable slice from the BigVector
    public fun borrow_slice_mut<Element: store>(bv: &mut BigVector, slice_idx: u64): &mut Slice<Element> {
        assert!(slice_idx <= bv.slice_idx, EIndexOutOfBounds);
        assert!(!is_empty(bv), EIsEmpty);

        borrow_slice_mut_(&mut bv.id, slice_idx)
    }
    fun borrow_slice_mut_<Element: store>(id: &mut UID, slice_idx: u64): &mut Slice<Element> {
        dynamic_field::borrow_mut(id, slice_idx)
    }

    /// borrow an element at index i from the BigVector
    public fun borrow_from_slice<Element: store>(slice: &Slice<Element>, i: u64): &Element {
        assert!(i < vector::length(&slice.vector), EIndexOutOfBounds);

        vector::borrow(&slice.vector, i)
    }

    /// borrow a mutable element at index i from the BigVector
    public fun borrow_from_slice_mut<Element: store>(slice: &mut Slice<Element>, i: u64): &mut Element {
        assert!(i < vector::length(&slice.vector), EIndexOutOfBounds);

        vector::borrow_mut(&mut slice.vector, i)
    }

    /// swap and pop the element at index i with the last element
    public fun swap_remove<Element: store>(bv: &mut BigVector, i: u64): Element {
        let result = pop_back(bv);
        if (i == length(bv)) {
            result
        } else {
            let slice = borrow_slice_mut_(&mut bv.id, i / (bv.slice_size as u64));
            vector::push_back(&mut slice.vector, result);
            vector::swap_remove(&mut slice.vector, i % (bv.slice_size as u64))
        }
    }

    /// remove the element at index i and shift the rest elements
    /// abort when reference more thant 1000 slices
    /// costly function, use wisely
    public fun remove<Element: store>(bv: &mut BigVector, i: u64): Element {
        assert!(i < length(bv), EIndexOutOfBounds);

        let slice = borrow_slice_mut_(&mut bv.id, (i / (bv.slice_size as u64)));
        let result = vector::remove(&mut slice.vector, i % (bv.slice_size as u64));
        let slice_idx = bv.slice_idx;
        while (slice_idx > i / (bv.slice_size as u64) && slice_idx > 0) {
            let slice = borrow_slice_mut_(&mut bv.id, slice_idx);
            let tmp: Element = vector::remove(&mut slice.vector, 0);
            let prev_slice = borrow_slice_mut_(&mut bv.id, slice_idx - 1);
            vector::push_back(&mut prev_slice.vector, tmp);
            slice_idx = slice_idx - 1;
        };
        trim_slice<Element>(bv);
        bv.length = bv.length - 1;

        result
    }

    /// drop BigVector, abort if it's not empty
    public fun destroy_empty(bv: BigVector) {
        let BigVector {
            id,
            element_type: _,
            slice_idx: _,
            slice_size: _,
            length,
        } = bv;
        assert!(length == 0, ENotEmpty);
        object::delete(id);
    }

    /// drop BigVector if element has drop ability
    /// abort when the BigVector contains more thant 1000 slices
    public fun drop<Element: store + drop>(bv: BigVector) {
        let BigVector {
            id,
            element_type: _,
            slice_idx,
            slice_size: _,
            length: _,
        } = bv;
        while (slice_idx > 0) {
            dynamic_field::remove<u64, Slice<Element>>(&mut id, slice_idx);
            slice_idx = slice_idx - 1;
        };
        dynamic_field::remove<u64, Slice<Element>>(&mut id, slice_idx);
        object::delete(id);
    }

    /// remove empty slice after element removal
    fun trim_slice<Element: store>(bv: &mut BigVector) {
        let slice = borrow_slice_(&bv.id, bv.slice_idx);
        if (vector::is_empty<Element>(&slice.vector)) {
            let Slice {
                idx: _,
                vector: v,
            } = dynamic_field::remove(&mut bv.id, bv.slice_idx);
            vector::destroy_empty<Element>(v);
            if (bv.slice_idx > 0) {
                bv.slice_idx = bv.slice_idx - 1;
            };
        };
    }
}

// #[test_only]
// module typus_framework::test_big_vector {
//     use std::vector;

//     use sui::test_scenario;

//     use typus_framework::big_vector::{Self, BigVector};

//     #[test]
//     fun test_big_vector_push_pop() {
//         let scenario = test_scenario::begin(@0xAAAA);
//         let big_vector = big_vector::new<u64>(2, test_scenario::ctx(&mut scenario));

//         // [1, 2], [3, 4], [5]
//         let count = 0;
//         while (count < 5) {
//             big_vector::push_back(&mut big_vector, count + 1);
//             count = count + 1;
//         };
//         assert_result(
//             &big_vector,
//             vector[
//                 vector[0, 1],
//                 vector[0, 2],
//                 vector[1, 3],
//                 vector[1, 4],
//                 vector[2, 5],
//             ],
//         );

//         // []
//         let count = 0;
//         while (count < 5) {
//             big_vector::pop_back<u64>(&mut big_vector);
//             count = count + 1;
//         };
//         assert_result(
//             &big_vector,
//             vector[],
//         );

//         // [1, 2], [3, 4], [5]
//         let count = 0;
//         while (count < 5) {
//             big_vector::push_back(&mut big_vector, count + 1);
//             count = count + 1;
//         };
//         assert_result(
//             &big_vector,
//             vector[
//                 vector[0, 1],
//                 vector[0, 2],
//                 vector[1, 3],
//                 vector[1, 4],
//                 vector[2, 5],
//             ],
//         );

//         // [1]
//         let count = 0;
//         while (count < 4) {
//             big_vector::pop_back<u64>(&mut big_vector);
//             count = count + 1;
//         };
//         assert_result(
//             &big_vector,
//             vector[
//                 vector[0, 1],
//             ],
//         );

//         // [1, 2], [3, 4], [5]
//         let count = 0;
//         while (count < 3) {
//             big_vector::push_back(&mut big_vector, count + 1);
//             count = count + 1;
//         };
//         assert_result(
//             &big_vector,
//             vector[
//                 vector[0, 1],
//                 vector[0, 1],
//                 vector[1, 2],
//                 vector[1, 3],
//             ],
//         );

//         big_vector::drop<u64>(big_vector);
//         test_scenario::end(scenario);
//     }

//     #[test]
//     fun test_big_vector_swap_remove() {
//         let scenario = test_scenario::begin(@0xAAAA);
//         let big_vector = big_vector::new<u64>(2, test_scenario::ctx(&mut scenario));

//         // [1, 2], [3, 4], [5]
//         let count = 0;
//         while (count < 5) {
//             big_vector::push_back(&mut big_vector, count + 1);
//             count = count + 1;
//         };
//         assert_result(
//             &big_vector,
//             vector[
//                 vector[0, 1],
//                 vector[0, 2],
//                 vector[1, 3],
//                 vector[1, 4],
//                 vector[2, 5],
//             ],
//         );

//         // [1, 2], [5, 4]
//         big_vector::swap_remove<u64>(&mut big_vector, 2);
//         assert_result(
//             &big_vector,
//             vector[
//                 vector[0, 1],
//                 vector[0, 2],
//                 vector[1, 5],
//                 vector[1, 4],
//             ],
//         );

//         // [4, 2], [5]
//         big_vector::swap_remove<u64>(&mut big_vector, 0);
//         assert_result(
//             &big_vector,
//             vector[
//                 vector[0, 4],
//                 vector[0, 2],
//                 vector[1, 5],
//             ],
//         );

//         big_vector::drop<u64>(big_vector);
//         test_scenario::end(scenario);
//     }

//     #[test]
//     fun test_big_vector_remove() {
//         let scenario = test_scenario::begin(@0xAAAA);
//         let big_vector = big_vector::new<u64>(2, test_scenario::ctx(&mut scenario));

//         // [1, 2], [3, 4], [5]
//         let count = 0;
//         while (count < 5) {
//             big_vector::push_back(&mut big_vector, count + 1);
//             count = count + 1;
//         };
//         assert_result(
//             &big_vector,
//             vector[
//                 vector[0, 1],
//                 vector[0, 2],
//                 vector[1, 3],
//                 vector[1, 4],
//                 vector[2, 5],
//             ],
//         );

//         // [1, 2], [4, 5]
//         big_vector::remove<u64>(&mut big_vector, 2);
//         assert_result(
//             &big_vector,
//             vector[
//                 vector[0, 1],
//                 vector[0, 2],
//                 vector[1, 4],
//                 vector[1, 5],
//             ],
//         );

//         // [2, 4], [5]
//         big_vector::remove<u64>(&mut big_vector, 0);
//         assert_result(
//             &big_vector,
//             vector[
//                 vector[0, 2],
//                 vector[0, 4],
//                 vector[1, 5],
//             ],
//         );

//         // [2, 5]
//         big_vector::remove<u64>(&mut big_vector, 1);
//         assert_result(
//             &big_vector,
//             vector[
//                 vector[0, 2],
//                 vector[0, 5],
//             ],
//         );

//         big_vector::drop<u64>(big_vector);
//         test_scenario::end(scenario);
//     }

//     #[test]
//     /// since dynamic_field::borrow is costly, iteration with borrow/borrow_mut is also costly
//     /// borrow each slice once and iterate the vector reduces the massive dynamic_field::borrow function
//     fun test_big_vector_iteration() {
//         let scenario = test_scenario::begin(@0xAAAA);
//         let big_vector = big_vector::new<u64>(2, test_scenario::ctx(&mut scenario));

//         // [1, 2], [3, 4], [5]
//         let count = 0;
//         while (count < 5) {
//             big_vector::push_back(&mut big_vector, count + 1);
//             count = count + 1;
//         };
//         assert_result(
//             &big_vector,
//             vector[
//                 vector[0, 1],
//                 vector[0, 2],
//                 vector[1, 3],
//                 vector[1, 4],
//                 vector[2, 5],
//             ],
//         );

//         big_vector::drop<u64>(big_vector);
//         test_scenario::end(scenario);
//     }

//     fun assert_result(
//         big_vector: &BigVector,
//         expected_result: vector<vector<u64>>,
//     ) {
//         // let current_slice_idx = big_vector::slice_idx(big_vector);
//         // let slice_idx = 0;
//         // while (slice_idx <= current_slice_idx) {
//         //     std::debug::print(big_vector::borrow_slice(big_vector, slice_idx));
//         //     slice_idx = slice_idx + 1;
//         // };
//         let result = vector::empty();
//         let length = big_vector::length(big_vector);
//         if (length > 0) {
//             let slice_size = (big_vector::slice_size(big_vector) as u64);
//             let slice_idx = 0;
//             let slice = big_vector::borrow_slice(big_vector, slice_idx);
//             let i = 0;
//             while (i < length) {
//                 vector::push_back(
//                     &mut result,
//                     vector[slice_idx, *vector::borrow(slice, i % slice_size)],
//                 );
//                 // std::debug::print(value);
//                 // jump to next slice
//                 if (i + 1 < length && (i + 1) % slice_size == 0) {
//                     slice_idx = (i + 1) / (slice_size as u64);
//                     slice = big_vector::borrow_slice(
//                         big_vector,
//                         slice_idx,
//                     );
//                 };
//                 i = i + 1;
//             };
//         };
//         assert!(expected_result == result, 0);
//     }
// }