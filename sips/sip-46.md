|  SIP-Number | 46 |
|        ---: | :--- |
|       Title | UNFT Standard - Unified NFT Standard for Sui |
| Description | A Unified NFT Standard for Sui NFTs with enforced limits, dual burn models, and global discoverability |
|      Author | tenxhunter \<tenxhunter@gmail.com \> |
|        Type | Standard |
|     Created | 2025-11-02 |
|      Status | Idea |

## Abstract

The UNFT (Universal NFT) Standard provides a composable supply tracking layer for Sui Move that enforces maximum supply limits, tracks minting and burning statistics, and enables global NFT collection discovery. Unlike monolithic NFT standards, UNFT does not dictate NFT structure—it accepts any UID, allowing it to work seamlessly with existing NFT implementations including Sui Kiosk, OriginByte, and custom marketplace solutions. The standard introduces a global registry pattern ensuring one authoritative collection per NFT type, capability-based authority models for minting and burning, and comprehensive event schemas for off-chain indexing.

## Motivation

### Current Problem

The Sui NFT ecosystem currently lacks a standardized approach to supply management:

1. **No Supply Enforcement**: Projects implement custom supply tracking in each contract, leading to inconsistent implementations and potential vulnerabilities
2. **Lack of Discoverability**: No standard way to discover all NFT collections or query collection metadata globally
3. **Reinvention Per Project**: Each NFT project reimplements minting limits, burn tracking, and supply caps independently
4. **Inconsistent Event Schemas**: Off-chain indexers must support numerous custom event formats for tracking NFT lifecycle events
5. **No Flexible Burn Models**: Existing solutions don't accommodate both centralized burn control (e.g., game items) and decentralized owner burns (e.g., art NFTs)

### Solution

UNFT Standard addresses these challenges through:

- **Lightweight Composability**: Works with ANY NFT implementation by only requiring access to the NFT's `UID`
- **Global Registry Pattern**: Ensures one authoritative collection per NFT type with Publisher-verified creation
- **Dual Burn Models**: Supports both centralized (BurnCap-controlled) and decentralized (owner-initiated) burn coordination
- **Type-Safe Capabilities**: Separate capabilities for minting, burning, and metadata management following the principle of least privilege
- **Standardized Events**: Comprehensive event schema enabling consistent off-chain indexing across all UNFT-compliant collections

## Specification

### Architecture Overview

UNFT Standard consists of three core shared objects:

1. **`NftRegistry`** - Global singleton for collection registration (one per package deployment)
2. **`NftCollection<T>`** - Type-parameterized supply tracking object
3. **`NftCollectionMetadata<T>`** - Type-parameterized metadata storage

These objects work together with capability-based authority:

- **`NftMintCap<T>`** - Proves authority to mint NFTs
- **`NftBurnCap<T>`** - Optional capability for centralized burn control
- **`NftCollectionMetadataCap<T>`** - Proves authority to update metadata

### Data Structures

#### NftCollection<T>

```move
struct NftCollection<phantom T> has key {
    id: UID,
    minted: u64,              // Total NFTs minted
    burned: u64,              // Total NFTs burned
    max_supply: Option<u64>,  // Hard supply cap (None = unlimited)
    paused: bool,             // Emergency pause state
    owner_burn_allowed: bool  // Burn coordination model flag
}
```

**Key Fields:**
- `minted` / `burned`: Atomic counters for supply tracking
- `max_supply`: Enforced on-chain supply limit (None for unlimited collections)
- `owner_burn_allowed`: Determines burn model (true = decentralized, false = centralized)

#### NftCollectionMetadata<T>

```move
struct NftCollectionMetadata<phantom T> has key {
    id: UID,
    name: String,
    description: String,
    image_url: String,
    external_url: String,
    decimals: u8,                  // Display hint (usually 0 for NFTs)
    max_supply_hint: Option<u64>,  // Soft UI-only supply target (non-enforced)
    pausable: bool,                // Whether collection can be paused
    metadata_frozen: bool,         // Permanent lock flag
    version: u8                    // Schema version (currently 1)
}
```

**Dual Supply Semantics:**
- `NftCollection::max_supply`: Hard cryptographic guarantee (enforced on-chain)
- `NftCollectionMetadata::max_supply_hint`: Soft marketing target (UI display only)

### Core Interfaces

#### Collection Creation

```move
public fun create_collection<T>(
    publisher: &Publisher,
    registry: &mut NftRegistry,
    max_supply: Option<u64>,
    owner_burn_allowed: bool,
    make_burn_cap: bool,
    // metadata fields...
    ctx: &mut TxContext
): (NftMintCap<T>, Option<NftBurnCap<T>>, NftCollectionMetadataCap<T>)
```

**Requirements:**
- `Publisher` proof from One-Time Witness (OTW) pattern
- Each NFT type `T` can only have one collection (enforced by registry)
- Choice of burn model is immutable after creation

**Parameters:**
- `max_supply`: None for unlimited, Some(n) for capped collections
- `owner_burn_allowed`: true = decentralized burns, false = centralized only
- `make_burn_cap`: Whether to create NftBurnCap (only for centralized model)

**Convenience Function:**
```move
public fun create_unlimited_collection<T>(
    publisher: &Publisher,
    registry: &mut NftRegistry,
    owner_burn_allowed: bool,
    // metadata fields...
    ctx: &mut TxContext
): (NftMintCap<T>, Option<NftBurnCap<T>>, NftCollectionMetadataCap<T>)
```

#### Supply Tracking

**Single Mint:**
```move
public fun track_mint<T>(
    _mint_cap: &NftMintCap<T>,
    collection: &mut NftCollection<T>,
    nft_id: &mut UID,
    ctx: &TxContext
)
```

Atomically:
1. Verifies supply limit not exceeded (`assert_can_mint`)
2. Increments `collection.minted`
3. Adds `collection_id` dynamic field to NFT's UID
4. Emits `MintedEvent<T>`

**Batch Mint (Gas Optimized):**
```move
public fun track_batch_mint<T>(
    _mint_cap: &NftMintCap<T>,
    collection: &mut NftCollection<T>,
    nft_ids: vector<&mut UID>,
    ctx: &TxContext
)
```

Emits single `BatchMintedEvent<T>` instead of N individual events.

**Centralized Burn:**
```move
public fun track_burn<T>(
    _burn_cap: &NftBurnCap<T>,
    collection: &mut NftCollection<T>,
    nft_id: &UID
)
```

Requires `NftBurnCap<T>`, aborts if `owner_burn_allowed = true`.

**Decentralized Burn:**
```move
public fun track_burn_by_owner<T>(
    collection: &mut NftCollection<T>,
    nft_id: &UID
)
```

Requires `owner_burn_allowed = true`, aborts if centralized model enabled.

#### Metadata Management

```move
public fun update_metadata<T>(
    _metadata_cap: &NftCollectionMetadataCap<T>,
    metadata: &mut NftCollectionMetadata<T>,
    // optional fields to update...
)
```

Emits `MetadataUpdatedEvent<T>` with bitmask indicating changed fields.

```move
public fun freeze_metadata<T>(
    metadata_cap: NftCollectionMetadataCap<T>,
    metadata: &mut NftCollectionMetadata<T>
)
```

Permanently locks metadata by consuming the capability. **Irreversible operation.**

#### Collection Control

```move
public fun pause_collection<T>(
    _metadata_cap: &NftCollectionMetadataCap<T>,
    metadata: &NftCollectionMetadata<T>,
    collection: &mut NftCollection<T>
)

public fun resume_collection<T>(
    _metadata_cap: &NftCollectionMetadataCap<T>,
    collection: &mut NftCollection<T>
)
```

Emergency pause/resume for minting operations (requires `pausable = true`).

```move
public fun finalize_supply<T>(
    _metadata_cap: &NftCollectionMetadataCap<T>,
    collection: &mut NftCollection<T>
)
```

Locks unlimited collection to current `minted` count. **Irreversible operation.**

#### Query Functions

```move
public fun supply<T>(collection: &NftCollection<T>): u64
public fun minted<T>(collection: &NftCollection<T>): u64
public fun burned<T>(collection: &NftCollection<T>): u64
public fun max_supply<T>(collection: &NftCollection<T>): Option<u64>
public fun remaining_supply<T>(collection: &NftCollection<T>): Option<u64>

public fun can_mint<T>(
    collection: &NftCollection<T>,
    quantity: u64
): bool
```

Pre-flight checks for mint eligibility.

### NFT Discovery

```move
public fun nft_collection_id(nft_id: &UID): ID
```

Extracts collection ID from NFT UID (aborts if not UNFT-registered).

```move
public fun try_nft_collection_id(nft_id: &UID): Option<ID>
```

Safe version returning `Option<ID>`.

```move
public fun has_collection_id(nft_id: &UID): bool
```

Check if NFT is UNFT-compliant.

### Event Schema

**Supply Events:**
- `MintedEvent<T>` - Single mint operation
- `BatchMintedEvent<T>` - Batch mint (gas optimized)
- `BurnedEvent<T>` - Burn operation

**Management Events:**
- `MetadataUpdatedEvent<T>` - Metadata changes (includes bitmask)
- `MetadataFrozenEvent<T>` - Metadata permanently frozen
- `CollectionPausedEvent<T>` / `CollectionResumedEvent<T>` - Pause state changes
- `SupplyFinalizedEvent<T>` - Supply locked

**Registry Events:**
- `RegistryInitializedEvent` - Registry deployment
- `CollectionRegisteredEvent<T>` - New collection registration

### Dual Burn Models

#### Centralized Burn Model (`make_burn_cap = true`)

**Use Cases:** Game items, subscription NFTs, regulatory compliance scenarios

**Characteristics:**
- Creates `NftBurnCap<T>` capability
- Only cap holder can burn via `track_burn()`
- Owner burn calls abort with `EOwnerBurnDisabled`
- Full control over NFT lifecycle

**Example:**
```move
// Game weapon that can be destroyed by game logic
let (mint_cap, burn_cap_opt, metadata_cap) = unft::create_collection<GameWeapon>(
    publisher,
    registry,
    option::some(10000),
    false,  // owner_burn_allowed = false
    true,   // make_burn_cap = true
    // ...
);

let burn_cap = option::extract(&mut burn_cap_opt);
// Game logic holds burn_cap and controls all burns
```

#### Decentralized Burn Model (`make_burn_cap = false`)

**Use Cases:** Art NFTs, collectibles, permissionless collections

**Characteristics:**
- No `NftBurnCap<T>` created
- Any NFT owner can burn their own NFT via `track_burn_by_owner()`
- Centralized burn calls abort
- Owner agency over their assets

**Example:**
```move
// Art NFT that owners can burn
let (mint_cap, burn_cap_opt, metadata_cap) = unft::create_collection<ArtNFT>(
    publisher,
    registry,
    option::some(100),
    true,   // owner_burn_allowed = true
    false,  // make_burn_cap = false
    // ...
);

assert!(option::is_none(&burn_cap_opt), 0);
// Owners call track_burn_by_owner() themselves
```

## Rationale

### Design Decisions

#### 1. Why Accept Any UID?

**Decision:** `track_mint<T>()` accepts `&mut UID` instead of requiring a specific NFT struct.

**Rationale:**
- Enables maximum composability with existing NFT implementations
- Separates concerns: UNFT = supply tracking, not full NFT implementation
- Works with Sui Kiosk, OriginByte, custom marketplaces without modification
- Allows projects to choose their own NFT structure and transfer policies

**Trade-off:**
- External modules must verify ownership before calling burn functions
- No built-in transfer policy enforcement (intentional—defer to Kiosk/TransferPolicy)

**Example Flexibility:**
```move
// Works with ANY of these:
struct SimpleNFT has key, store { id: UID }
struct GameNFT has key, store { id: UID, power: u64, rarity: u8 }
struct MusicNFT has key, store { id: UID, track_url: String, artist: address }

// UNFT only needs the UID
unft::track_mint(&mint_cap, &mut collection, &mut nft.id, ctx);
```

#### 2. Why Global Registry Pattern?

**Decision:** One `NftRegistry` per deployment, one collection per type `T`.

**Rationale:**
- **Discoverability**: Anyone can find the authoritative collection for type `T`
- **Type Safety**: Prevents duplicate collections with conflicting supply counts
- **Single Source of Truth**: No ambiguity about which collection is canonical
- **Publisher Verification**: Only package with OTW can register, preventing spoofing

**Alternative Considered:** Allow multiple collections per type.
**Rejected Because:** Would fragment supply tracking and break global discovery.

#### 3. Why Two Burn Models?

**Decision:** Immutable choice between centralized (BurnCap) and decentralized (owner burn) at collection creation.

**Rationale:**
- **Different Use Cases**: Game items need developer control, art NFTs need owner agency
- **Security**: Immutable choice prevents privilege escalation attacks
- **Transparency**: On-chain record of burn model (via `owner_burn_allowed` field)

**Alternative Considered:** Allow both models simultaneously.
**Rejected Because:** Would create ambiguity and potential security issues if both burn paths were active.

#### 4. Why Separate Capabilities?

**Decision:** `NftMintCap<T>`, `NftBurnCap<T>`, and `NftCollectionMetadataCap<T>` are separate objects.

**Rationale:**
- **Principle of Least Privilege**: Delegate minting without exposing burn/metadata rights
- **Capability Composition**: Complex scenarios (e.g., minting vending machine with separate admin)
- **Security**: Reduces attack surface by limiting each capability's scope

**Example:**
```move
// Transfer mint cap to vending machine
transfer::public_transfer(mint_cap, vending_machine_address);
// Keep burn and metadata caps with admin
transfer::transfer(metadata_cap, admin_address);
```

#### 5. Why max_supply vs max_supply_hint?

**Decision:** Two supply fields with different semantics.

**Rationale:**
- **`max_supply` (NftCollection)**: Hard on-chain enforcement, cryptographic guarantee
- **`max_supply_hint` (NftCollectionMetadata)**: Soft UI target for marketing flexibility

**Use Case:**
```move
// Cryptographically guarantee never exceed 10,000
max_supply: Some(10000),
// Display "Limited Edition: 1000 Special Mint" in UI
max_supply_hint: Some(1000),
```

Allows creators to have flexible marketing campaigns within hard supply boundaries.

### Trade-offs

**Composability vs Enforcement:**
- ✅ **Pro**: Extreme composability—works with any NFT implementation
- ⚠️ **Con**: External modules responsible for ownership verification before burns
- **Mitigation**: Clear documentation and example implementations

**Type Safety vs Migration:**
- ✅ **Pro**: Type parameter `T` ensures capability-collection matching
- ⚠️ **Con**: Cannot migrate existing collections to new contract versions
- **Mitigation**: Version field in metadata for future schema evolution

**Gas Optimization vs Shared Object Overhead:**
- ✅ **Pro**: Batch operations reduce per-NFT event emission costs
- ⚠️ **Con**: Shared objects have higher consensus overhead than owned objects
- **Mitigation**: Batch functions for high-volume mints (e.g., airdrops)

## Backwards Compatibility

No backwards compatibility issues as this is a new standard.

**Compatibility with Existing Standards:**
- Works alongside Sui Kiosk (UNFT tracks supply, Kiosk handles transfers/royalties)
- Compatible with TransferPolicy (UNFT doesn't enforce transfer rules)
- Can be integrated with OriginByte and other NFT frameworks

**Non-Breaking for Non-Users:**
- NFT types that don't use UNFT are unaffected
- No changes to Sui Framework required

## Security Considerations

### Security Strengths

1. **Publisher Verification**
   ```move
   assert!(publisher.from_package<T>(), EInvalidPublisher);
   ```
   Ensures only the package with One-Time Witness for `T` can create collections.

2. **Type Safety**
   Generic parameter `T` cryptographically links capabilities to collections—`NftMintCap<GameNFT>` cannot mint `ArtNFT`.

3. **Registry Uniqueness**
   ```move
   assert!(!registry.contains(type_name<T>()), ECollectionAlreadyExists);
   ```
   Prevents duplicate collections per type.

4. **Atomic Supply Checks**
   ```move
   fun assert_can_mint<T>(collection: &NftCollection<T>, quantity: u64) {
       if (option::is_some(&collection.max_supply)) {
           let max = *option::borrow(&collection.max_supply);
           assert!(collection.minted + quantity <= max, EMaxSupplyReached);
       }
   }
   ```
   Race condition safe (shared object consensus ensures atomicity).

5. **Dynamic Field Isolation**
   Uses typed `CollectionIdKey` to prevent cross-module dynamic field conflicts.

### Known Limitations

1. **External Ownership Verification**

   `track_mint<T>()` accepts any `&mut UID`. Caller modules MUST verify NFT ownership before burns.

   **Safe Pattern:**
   ```move
   public fun burn_nft(collection: &mut NftCollection<MyNFT>, nft: MyNFT) {
       let MyNFT { id } = nft;  // Proof of ownership via unpacking
       unft::track_burn_by_owner(&mut collection, &id);
       object::delete(id);
   }
   ```

   **Unsafe Pattern:**
   ```move
   // DON'T DO THIS
   public fun burn_nft(collection: &mut NftCollection<MyNFT>, nft_id: &UID) {
       unft::track_burn_by_owner(&mut collection, nft_id);  // No ownership check!
   }
   ```

2. **No Floor Price Validation**

   UNFT cannot validate Kiosk floor prices at mint time (would require Kiosk integration). Projects using Kiosk should validate separately.

3. **Metadata Freeze Irreversibility**

   `freeze_metadata()` is permanent. Ensure metadata is finalized before freezing.

4. **Supply Finalization Irreversibility**

   `finalize_supply()` permanently locks unlimited collections. Cannot be undone.

### Caller Responsibilities

**NFT Implementation Module MUST:**
1. Verify ownership before calling burn functions
2. Validate that NFT being minted/burned is correctly typed
3. Implement Kiosk/TransferPolicy compliance if applicable
4. Store capabilities securely (MintCap, BurnCap, MetadataCap)

**Best Practice:**
```move
// Good: Ownership verified by struct unpacking
public fun mint_and_track(
    mint_cap: &NftMintCap<MyNFT>,
    collection: &mut NftCollection<MyNFT>,
    ctx: &mut TxContext
): MyNFT {
    let nft = MyNFT { id: object::new(ctx) };
    unft::track_mint(mint_cap, collection, &mut nft.id, ctx);
    nft
}

public fun burn_and_track(
    collection: &mut NftCollection<MyNFT>,
    nft: MyNFT  // Taking by value proves ownership
) {
    let MyNFT { id } = nft;
    unft::track_burn_by_owner(collection, &id);
    object::delete(id);
}
```

## Reference Implementation

### Deployed Contract

**Package Address:** `0x7f828b16dd9b25ed5b7406bfdc9be79de1fbb36f0968ae3e9628f659fb1f9305`

**Source Code:** [unft_standard](https://github.com/Foundation3DAO/unft_standard)

**Documentation:** [README.md](https://github.com/Foundation3DAO/unft_standard/README.md)

### Integration Examples

#### Example 1: Simple Character NFT

```move
module my_game::character {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use unft_standard::unft_standard as unft;

    struct Character has key, store {
        id: UID,
        level: u8,
        class: String
    }

    struct CHARACTER has drop {}

    fun init(otw: CHARACTER, ctx: &mut TxContext) {
        let publisher = package::claim(otw, ctx);

        let (mint_cap, burn_cap, metadata_cap) = unft::create_collection<Character>(
            &publisher,
            registry,
            option::some(10000),  // Max 10k characters
            true,                 // Owners can burn
            false,                // No centralized burn cap
            string::utf8(b"Game Characters"),
            string::utf8(b"Playable game characters"),
            // ... metadata fields
            ctx
        );

        transfer::public_transfer(mint_cap, tx_context::sender(ctx));
        transfer::public_transfer(metadata_cap, tx_context::sender(ctx));
        transfer::public_share_object(publisher);
    }

    public fun mint_character(
        mint_cap: &unft::NftMintCap<Character>,
        collection: &mut unft::NftCollection<Character>,
        level: u8,
        class: String,
        ctx: &mut TxContext
    ): Character {
        let character = Character {
            id: object::new(ctx),
            level,
            class
        };

        unft::track_mint(mint_cap, collection, &mut character.id, ctx);
        character
    }

    public fun burn_character(
        collection: &mut unft::NftCollection<Character>,
        character: Character
    ) {
        let Character { id, level: _, class: _ } = character;
        unft::track_burn_by_owner(collection, &id);
        object::delete(id);
    }
}
```

#### Example 2: Limited Edition Art with Supply Finalization

```move
module art_studio::limited_edition {
    use unft_standard::unft_standard as unft;

    struct LimitedArt has key, store {
        id: UID,
        edition_number: u64,
        artist_signature: String
    }

    struct LIMITED_ART has drop {}

    fun init(otw: LIMITED_ART, ctx: &mut TxContext) {
        let publisher = package::claim(otw, ctx);

        // Start with unlimited, will finalize after mint
        let (mint_cap, burn_cap, metadata_cap) = unft::create_unlimited_collection<LimitedArt>(
            &publisher,
            registry,
            true,  // Owners can burn
            string::utf8(b"Sunrise Series"),
            string::utf8(b"Limited edition photography"),
            // ... metadata
            ctx
        );

        transfer::public_transfer(mint_cap, tx_context::sender(ctx));
        transfer::public_transfer(metadata_cap, tx_context::sender(ctx));
        transfer::public_share_object(publisher);
    }

    // After minting exactly 100 pieces...
    public fun finalize_collection(
        metadata_cap: &unft::NftCollectionMetadataCap<LimitedArt>,
        collection: &mut unft::NftCollection<LimitedArt>
    ) {
        // Lock collection to current supply (100)
        unft::finalize_supply(metadata_cap, collection);
        // Now max_supply = Some(100), cannot mint more
    }
}
```

#### Example 3: Game Weapon with Centralized Burn

```move
module rpg::weapons {
    use unft_standard::unft_standard as unft;

    struct Weapon has key, store {
        id: UID,
        durability: u64,
        power: u64
    }

    struct WEAPON has drop {}

    fun init(otw: WEAPON, ctx: &mut TxContext) {
        let publisher = package::claim(otw, ctx);

        let (mint_cap, burn_cap_opt, metadata_cap) = unft::create_collection<Weapon>(
            &publisher,
            registry,
            option::none(),  // Unlimited
            false,           // Owner cannot burn
            true,            // Create burn cap
            string::utf8(b"Legendary Weapons"),
            string::utf8(b"Powerful weapons for RPG combat"),
            // ... metadata
            ctx
        );

        let burn_cap = option::extract(&mut burn_cap_opt);

        transfer::public_transfer(mint_cap, tx_context::sender(ctx));
        transfer::public_transfer(burn_cap, tx_context::sender(ctx));
        transfer::public_transfer(metadata_cap, tx_context::sender(ctx));
        transfer::public_share_object(publisher);
    }

    // Only game logic with burn_cap can destroy broken weapons
    public fun destroy_broken_weapon(
        burn_cap: &unft::NftBurnCap<Weapon>,
        collection: &mut unft::NftCollection<Weapon>,
        weapon: Weapon
    ) {
        assert!(weapon.durability == 0, EWeaponNotBroken);

        let Weapon { id, durability: _, power: _ } = weapon;
        unft::track_burn(burn_cap, collection, &id);
        object::delete(id);
    }
}
```

### Test Coverage

The reference implementation includes 61+ comprehensive tests covering:

- Collection creation and initialization
- Single and batch minting with supply limits
- Centralized and decentralized burn models
- Metadata updates and freezing
- Pause/resume functionality
- Supply finalization
- Edge cases (Unicode, zero values, boundary conditions)
- Gas optimization validation
- NFT discovery helpers

**Test Files:**
- `tests/unft_standard_tests.move` - Core functionality
- `tests/unft_discoverability_tests.move` - NFT discovery
- `tests/edge_case_tests.move` - Edge cases and error conditions
- `tests/gas_optimization_tests.move` - Batch operation efficiency

## Copyright

Copyright and related rights waived via [CC0](https://creativecommons.org/publicdomain/zero/1.0/).
