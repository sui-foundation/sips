|   SIP-Number | TBD |
|         ---: | :--- |
|        Title | Custom Transfer Handler Support for Sui Wallet |
|  Description | Standardize custom transfer behavior to support business logic |
|       Author | Tushar Sengar |
|       Editor | TBD |
|         Type | Standard |
|     Category | Wallet |
|      Created | 2024-12-09 |
| Comments-URI | https://sips.sui.io/comments-TBD |
|       Status | Draft |
|     Requires | |

## Abstract

Introduce a standardized custom transfer handler interface in the Sui wallet to support assets with custom business logic, such as NFTs that require additional state updates or validation during transfers.

## Motivation

Many Sui protocols implement sophisticated transfer logic that goes beyond simple ownership changes. For example:
- Artinals NFTs maintain complex state and require custom transfer functions
- Gaming NFTs need to track player statistics during transfers
- DeFi NFTs must update liquidity pools
- Governance tokens need to adjust voting power
- Music/Art NFTs distribute royalties on transfer

Currently, these protocols must choose between wallet compatibility and maintaining protocol integrity. This leads to fragmented user experiences and limits protocol functionality.

## Proposal

Introduce a new `CustomTransferHandler` trait and modify the Sui wallet to support custom transfer implementations:

### CustomTransferHandler Trait

module sui::custom_transfer {
    struct CustomTransferInfo has copy, drop {
        module_address: address,
        function_name: vector<u8>,
        required_args: vector<TypeTag>
    }

    public trait CustomTransferHandler {
        /// Check if asset implements custom transfer
        fun supports_custom_transfer<T: key + store>(asset: &T): bool;
        
        /// Get custom transfer implementation details
        fun get_custom_transfer<T: key + store>(asset: &T): Option<CustomTransferInfo>;
    }
}


### Wallet Integration
1. When initiating a transfer, check if the asset implements `CustomTransferHandler`
2. If implemented:
   - Get custom transfer details via `get_custom_transfer`
   - Use the specified module/function for transfer
   - Display custom transfer UI if additional arguments needed
3. If not implemented:
   - Use default `transfer::public_transfer`

### Example Implementation

module artinals::transfer_handler {
    use sui::custom_transfer::{Self, CustomTransferHandler, CustomTransferInfo};
    
    struct NFT has key, store { ... }
    
    impl CustomTransferHandler for NFT {
        public fun supports_custom_transfer<T: key + store>(asset: &T): bool {
            std::type_name::get<T>() == std::type_name::get<NFT>()
        }
        
        public fun get_custom_transfer<T: key + store>(asset: &T): Option<CustomTransferInfo> {
            if (supports_custom_transfer(asset)) {
                option::some(CustomTransferInfo {
                    module_address: @artinals,
                    function_name: b"transfer_art20",
                    required_args: vector[type_tag<UserBalance>()]
                })
            } else {
                option::none()
            }
        }
    }
}


## Benefits

1. **Protocol Integrity**: Assets can maintain complex state during transfers
2. **Better UX**: Unified transfer experience in wallet
3. **Standardization**: Common interface for custom transfer logic
4. **Security**: Explicit declaration and validation of custom handlers
5. **Flexibility**: Protocols can evolve transfer logic without breaking wallet support

## Implementation

### Wallet Changes
1. Add custom transfer handler detection
2. Implement UI for additional transfer arguments
3. Add custom transfer validation
4. Include user notifications for custom transfers

### Security Considerations
1. Custom transfers must be explicitly declared via trait
2. Wallet validates custom transfer implementations
3. Users are notified when custom handler is used
4. Rate limiting and gas optimization for complex transfers

## Backward Compatibility

This proposal maintains full backward compatibility:
1. Existing assets continue using default transfer
2. Only assets implementing `CustomTransferHandler` use custom logic
3. No changes required for existing protocols
4. Gradual adoption possible as protocols add support

## Reference Implementation

Example implementation showing Artinals NFT integration:
```move
public entry fun transfer_art20(
    token: NFT,
    recipient: address,
    user_balance: &mut UserBalance,
    ctx: &mut TxContext
) {
    // Update protocol state
    update_balance(user_balance);
    
    // Perform transfer
    transfer::public_transfer(token, recipient);
}
```

## Timeline

1. Phase 1 (Week 1-2):
   - Implement `CustomTransferHandler` trait
   - Add basic wallet detection

2. Phase 2 (Week 3-4):
   - Add UI support for custom arguments
   - Implement validation

3. Phase 3 (Week 5-6):
   - Beta testing with select protocols
   - Security audits

4. Phase 4 (Week 7-8):
   - Mainnet deployment
   - Documentation and developer guides

## Copyright

[CC0 1.0](../LICENSE.md).