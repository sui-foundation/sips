|   SIP-Number | |
|         ---: | :--- |
|        Title | String Formatting Utilities for Move |
|  Description | Introduces a standard module and macros for formatting strings and values in Move using builder pattern and template replacement |
|       Author | BlockchainBard <@blockchainBard101>, <bchainbard.annonymousasquare@gmail.com> |
|       Editor | |
|         Type | Standard |
|     Category | Framework |
|      Created | 2025-07-22 |
| Comments-URI | |
|       Status | |
|     Requires | |

## Abstract

This SIP proposes adding a formatting utility module to the Sui standard library. It provides two approaches for formatting: a template-style function that replaces `{}` placeholders with values, and a builder-style API that allows programmatic composition of strings from a variety of types. It also includes macros for appending numeric values and other types.

## Motivation

Move currently lacks a convenient, consistent mechanism for formatting strings. Developers often rely on manual string concatenation or verbose conversions of values to strings. This limits readability, reusability, and developer ergonomics. The proposed formatter module aims to provide a common, lightweight utility that simplifies constructing user-friendly string outputs, especially for debugging, logging, and displaying transaction metadata.

## Specification

This module defines:

- A `Formatter` struct that holds intermediate parts of a string.
- Builder-style methods to append values: `add_string`, `add_u64`, `add_u8`, `add_address`, `add_bool`, `add_bytes`, etc.
- A `build()` method that concatenates all parts into a final `String`.
- A `format_template` function that replaces `{}` in a string template with positional values from a `vector<String>`.
- A macro `add_number!()` to generically add any numeric value.

Key signatures:
```move
public fun format_template(template: String, values: vector<String>): String;

public fun new_formatter(): Formatter;

public fun Formatter::add_u64(self, value: u64): Formatter;
public fun Formatter::build(self): String;
````

## Rationale

Two formatting styles were included:

* `format_template`: Useful for simple static templates with dynamic inserts.
* `Formatter`: Builder pattern for programmatic formatting, useful for multi-step construction or dynamic content.

This approach avoids runtime format string parsing or unsafe behavior while remaining expressive. It follows Move’s idioms, avoids reflection or dynamic typing, and has zero dependencies.

The builder pattern is a common approach in typed languages where variadic or polymorphic formatting is unavailable. The use of macros (`num_to_string!`) ensures numerical values are converted consistently.

### Pros

* Developer ergonomics
* Clean abstraction over manual string handling
* Future extensibility (e.g., number formatting, hex, padding)

### Cons

* Slight increase in binary size
* Requires documentation and education to use effectively

## Backwards Compatibility

No changes to existing APIs. This proposal is purely additive and does not introduce breaking changes.


## Test Cases

The module includes test functions demonstrating:

* Template formatting with `{}` placeholders
* Chaining of builder methods to append multiple types
* Correct output formatting of addresses, numbers, booleans, and byte vectors


## Reference Implementation

GitHub Repository: [blockchainbard/sui-string-formatter](https://github.com/blockchainBard101/formatter)
This includes:

* Complete `formatter::formatter` module
* Unit tests and usage examples
* Macro definitions for numeric formatting

## Security Considerations

None. This utility module performs only string manipulation and does not affect transaction validation, storage, or privileges.

## Copyright

[CC0 1.0](../LICENSE.md)
