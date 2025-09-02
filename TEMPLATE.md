|   SIP-Number |  |
|         ---: | :--- |
|        Title | Standardized Tokenized Vault Interface for Sui |
|  Description | A unified, composable, and auditable interface for tokenized vaults on Sui to enable standardized integrations across DeFi protocols. |
|       Author | Ali Ercan Ozgokce <ali@rivalabs.io>, Osman Gocer <osman@rivalabs.io>, Doga Ozcan <doga@rivalabs.io> |
|       Editor |  |
|         Type | Standard |
|     Category | Application |
|      Created | 2025-09-2 |
| Comments-URI |  |
|       Status |  |
|     Requires |  |


## Abstract

This SIP introduces a standardized interface for tokenized vaults on the Sui blockchain. By defining a minimal, composable, and auditable standard, this proposal aims to unify vault interactions across protocols, making yield-bearing assets and vault integrations consistent, secure, and developer-friendly.

## Motivation

Tokenized vaults have become a foundational component of decentralized finance (DeFi), powering yield optimization, automated strategies, and liquidity aggregation. However, the lack of a standardized interface on Sui creates the following issues:

- Fragmentation: Different vault implementations lead to incompatibility and isolated ecosystems.

- Complex Integrations: Developers must write custom adapters for each vault protocol, slowing down innovation.

- Auditing Challenges: Non-standardized logic complicates security reviews and on-chain verification.

Inspired by the success of ERC-4626 in the EVM ecosystem, this SIP proposes a native, Move-based standard tailored for the unique architecture and performance requirements of Sui.

## Specification

Below is the reference Move implementation of the standardized vault module:

```move
module vault::vault;

// === Imports ===

use std::string::String;
use std::u64::pow;
use sui::balance::{Self, Balance};
use sui::coin::{Coin, TreasuryCap};
use sui::dynamic_object_field as dof;
use sui::url::Url;

// === Constants ===
const MAX_U64: u128 = 18446744073709551615;

// === Error Constants ===

/// When the provided OwnerCap doesn't match the vault's ID
const EWrongOwnerCap: u64 = 1;
/// When trying to withdraw more than available in reserves
const EInsufficientReserves: u64 = 2;
/// When the exchange rate is zero
const EInvalidRate: u64 = 3;
/// When the provided VaultMetadata doesn't belong to this vault
const EInvalidMetadata: u64 = 4;
/// When arithmetic operation would cause overflow
const EArithmeticOverflow: u64 = 5;
/// When division by zero would occur
const EDivisionByZero: u64 = 6;

// === Structs ===

/// Main vault struct for managing coin exchanges
public struct Vault<phantom InputCoin, phantom OutputCoin> has key, store {
    id: UID,
    /// Exchange rate multiplier for input to output conversion
    rate: u64,
    /// Balance of input coins held in reserve
    reserve: Balance<InputCoin>,
    /// Decimals of the rate
    rate_decimals: u8,
}

/// Metadata for the vault containing display information
public struct VaultMetadata<phantom InputCoin, phantom OutputCoin> has key, store {
    id: UID,
    name: String,
    symbol: String,
    description: String,
    icon_url: Option<Url>,
}

/// Owner capability for vault administration
public struct OwnerCap has key, store {
    id: UID,
    vault_id: ID,
}

// === Public Functions ===

/// Creates a new vault with the specified parameters
/// Returns the vault shared object and transfers ownership capability to sender
#[allow(lint(self_transfer))]
public fun create_vault<InputCoin, OutputCoin>(
    rate: u64,
    output_coin_treasury: TreasuryCap<OutputCoin>,
    rate_decimals: u8,
    symbol: vector<u8>,
    name: vector<u8>,
    description: vector<u8>,
    icon_url: Option<Url>,
    ctx: &mut TxContext,
) {
    let mut vault = create_vault_inner<InputCoin, OutputCoin>(
        rate,
        rate_decimals,
        ctx,
    );
    
    let vault_metadata = create_vault_metadata_inner<InputCoin, OutputCoin>(
        name,
        symbol,
        description,
        icon_url,
        ctx,
    );

    let owner_cap = OwnerCap {
        id: object::new(ctx),
        vault_id: vault.id.to_inner(),
    };

    dof::add(&mut vault.id, vault_metadata.id.to_inner(), output_coin_treasury);

    transfer::freeze_object(vault_metadata);
    transfer::public_transfer(owner_cap, ctx.sender());
    transfer::share_object(vault);
}

// === Owner Functions ===

/// Deposits input coins into the vault (owner only)
/// Returns the owner capability to the sender
public fun deposit<InputCoin, OutputCoin>(
    owner_cap: &OwnerCap,
    vault: &mut Vault<InputCoin, OutputCoin>,
    amount: Coin<InputCoin>,
) {
    assert_owner_cap_matches(vault, owner_cap);
    vault.reserve.join(amount.into_balance());
}

/// Withdraws input coins from the vault reserves (owner only)
/// Returns the withdrawn coins and owner capability to the sender
public fun withdraw<InputCoin, OutputCoin>(
    owner_cap: &OwnerCap,
    vault: &mut Vault<InputCoin, OutputCoin>,
    amount: u64,
    ctx: &mut TxContext,
): Coin<InputCoin> {
    assert_owner_cap_matches(vault, owner_cap);
    assert!(vault.reserve.value() >= amount, EInsufficientReserves);
    vault.reserve.split(amount).into_coin(ctx)
}

/// Updates the exchange rate for the vault (owner only)
/// Returns the owner capability to the sender
public fun set_rate<InputCoin, OutputCoin>(
    owner_cap: &OwnerCap,
    vault: &mut Vault<InputCoin, OutputCoin>,
    rate: u64,
) {
    assert_owner_cap_matches(vault, owner_cap);
    assert!(rate > 0, EInvalidRate);
    vault.rate = rate;
}

// === User Functions ===

/// Exchanges input coins for output coins based on vault's exchange rate
/// Input coins are added to reserves, output coins are minted from supply
public fun mint<InputCoin, OutputCoin>(
    vault: &mut Vault<InputCoin, OutputCoin>,
    vault_metadata: &VaultMetadata<InputCoin, OutputCoin>,
    input_coin: Coin<InputCoin>,
    ctx: &mut TxContext,
): Coin<OutputCoin> {
    assert_metadata_matches(vault, vault_metadata);
    
    let input_value = input_coin.value();
    let output_amount = calculate_output_amount_safe(
        vault.rate,
        input_value,
        vault.rate_decimals,
    );

    vault.reserve.join(input_coin.into_balance());
    
    dof::borrow_mut<ID, TreasuryCap<OutputCoin>>(
        &mut vault.id,
        vault_metadata.id.to_inner(),
    ).mint(output_amount, ctx)
}

/// Exchanges output coins for input coins based on vault's exchange rate
/// Output coins are burned from supply, input coins are taken from reserves
public fun redeem<InputCoin, OutputCoin>(
    vault: &mut Vault<InputCoin, OutputCoin>,
    vault_metadata: &VaultMetadata<InputCoin, OutputCoin>,
    output_coin: Coin<OutputCoin>,
    ctx: &mut TxContext,
): Coin<InputCoin> {
    assert_metadata_matches(vault, vault_metadata);
    
    let output_value = output_coin.value();
    let input_amount = calculate_input_amount_safe(
        vault.rate,
        output_value,
        vault.rate_decimals,
    );
    
    assert!(vault.reserve.value() >= input_amount, EInsufficientReserves);

    let input_coin = vault.reserve.split(input_amount).into_coin(ctx);
    
    dof::borrow_mut<ID, TreasuryCap<OutputCoin>>(
        &mut vault.id,
        vault_metadata.id.to_inner(),
    ).burn(output_coin);

    input_coin
}
```

## Rationale

Design Choices

- Minimalism: Keeping the interface lean ensures ease of adoption while allowing extensions for advanced use cases.

- Composability: Encourages interoperability between vaults, DEX aggregators, lending protocols, and future modular DeFi systems.

- Auditable: A single, well-defined standard reduces security risk and simplifies code audits.

Trade-Offs

- Migration Overhead: Existing non-standard vaults will need wrapper contracts to ensure compliance.

- Flexibility Constraints: Strict adherence to the interface may limit certain niche implementations, but this is offset by increased ecosystem-wide composability.

## Backwards Compatibility

This SIP introduces no breaking changes for existing protocols. For legacy vaults, thin wrappers or adapter layers can be implemented to achieve compliance without requiring full redeployment.

## Test Cases

| Category    | Scenario                           | Tests                                                                                                                                                         | Expected / Abort                                                                  |
| ----------- | ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| Init        | Vault created with correct params  | `test_create_vault_functionality`                                                                                                                             | `rate==RATE`, `reserve==0`, owner cap valid                                       |
| Owner Ops   | Deposit / Withdraw                 | `test_deposit_functionality`, `test_withdraw_functionality`                                                                                                   | Reserve increases by deposit; exact withdraw returns amount, updates reserve      |
| User Ops    | Mint / Redeem                      | `test_mint_functionality`, `test_redeem_functionality`                                                                                                        | Mint: output = floor(input·rate/10^dec); Redeem: input = ceil(output·10^dec/rate) |
| Math        | Conversion correctness             | `test_output_amount_calculation`, `test_input_amount_calculation`                                                                                             | Calculations match expected amounts across sizes                                  |
| Edge Inputs | Tiny & zero inputs                 | `test_underflow_and_precision_loss`, `test_edge_cases_zero_values`                                                                                            | Rounds down to 0 until threshold; zero → zero                                     |
| Decimals    | Alternate decimal scales           | `test_different_rate_decimals`                                                                                                                                | Correct results with `rate_decimals = 6`                                          |
| Auth        | Wrong owner cap                    | `test_wrong_owner_cap_fails`                                                                                                                                  | **Abort `EWrongOwnerCap`**                                                        |
| Liquidity   | Insufficient reserves              | `test_insufficient_reserves_fails`                                                                                                                            | **Abort `EInsufficientReserves`**                                                 |
| Guardrails  | Zero rate / Overflow / Div-by-zero | `test_create_vault_zero_rate_fails`, `test_overflow_protection_mint_fails`, `test_overflow_protection_redeem_fails`, `test_division_by_zero_protection_fails` | **Abort `EInvalidRate`**, **`EArithmeticOverflow`**, **`EDivisionByZero`**        |


## Reference Implementation

Vault Contracts (Move):
https://github.com/riva-labs/vault-contracts

Includes reference implementations and modular templates for different asset classes.

TypeScript SDK:
https://github.com/riva-labs/vault-sdk

https://www.npmjs.com/package/@riva-labs/sdk

Provides high-level abstractions for developers, enabling seamless interaction with compliant vault contracts.

## Security Considerations

- OwnerCap custody (single admin).
The holder of OwnerCap can call deposit, withdraw, and set_rate. If compromised, reserves can be withdrawn and the rate changed. Custody this capability securely; never pass it through third-party modules.

- Rate control affects user outcomes.
set_rate lets the owner change conversion immediately. This directly changes mint/redeem amounts. Integrations should read rate() on each interaction and surface it to users.

- Arithmetic safety & rounding.
Conversions use checked integer arithmetic (u128 intermediates, u64 bounds) with zero-rate rejected; mint rounds down and redeem rounds up. This conservative rounding prevents over-minting—very small deposits can yield 0, and redemptions require enough reserves to cover the rounded amount.


## Copyright

[CC BY 4.0](https://github.com/riva-labs/vault-contracts/blob/main/LICENSE).
