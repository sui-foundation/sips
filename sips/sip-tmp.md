
| SIP-Number | <Leave this blank; it will be assigned by a SIP Editor> |
| ---: | :--- |
| Title | Transaction Expiration Timestamp Granularity |
| Description | Change transaction.setExpiration from epoch to timestamp granularity using Unix milliseconds. |
| Author | Pika <pika@cetus.zone, @RandyPen> |
| Editor | <Leave this blank; it will be assigned by a SIP Editor> |
| Type | Standard |
| Category | Interface |
| Created | 2025-12-15 |
| Comments-URI | <Leave this blank; it will be assigned by a SIP Editor> |
| Status | <Leave this blank; it will be assigned by a SIP Editor> |
| Requires | N/A |

## Abstract

This SIP proposes changing the `transaction.setExpiration` function from epoch-based granularity to timestamp-based granularity using Unix timestamps in milliseconds. This improvement allows objects and accounts locked due to transaction submission issues to be released earlier than one epoch, significantly improving user experience when transactions encounter submission problems.

## Motivation

When transactions are submitted to RPC nodes in the Sui network, they may be assigned to different validators based on network conditions and load balancing. This can cause objects to become locked, preventing users from submitting further transactions with those objects. Currently, objects remain locked for at least one full epoch before being automatically released, which typically lasts several hours.

Many users encounter this issue through wallet applications and don't understand how to resolve it, leading to complaints about Sui network problems. The current epoch-based expiration mechanism creates extended lock times, poor error messaging, and transaction failures due to temporary submission issues.

## Specification

### API Changes

- **Current API**: `transaction.setExpiration(epoch: number): Transaction`
- **Proposed API**: `transaction.setExpiration(timestampMs: number): Transaction`

### Timestamp Format

- **Format**: Unix timestamp in milliseconds
- **Precision**: Millisecond precision (1ms = 0.001 seconds)
- **Reference**: Milliseconds since January 1, 1970, 00:00:00 UTC
- **Minimum Value**: Current timestamp + 1000ms (1 second minimum expiration)
- **Maximum Value**: Current timestamp + 86,400,000ms (24 hours maximum expiration)

### Minimum Expiration Duration

- **Minimum**: 1 second (1000 milliseconds)
- **Rationale**: Provides sufficient time for transaction processing while allowing quick release
- **Validation**: API should reject timestamps less than current time

### Behavior Changes

1. **Transaction Submission**: When a transaction is submitted, the expiration timestamp is recorded
2. **Object Lock Release**: Objects locked by expired transactions are immediately available for new transactions
3. **Backwards Compatibility Layer**: Maintain support for epoch-based expiration during transition period

## Rationale

### Design Decisions

1. **Unix Timestamp in Milliseconds**: Standardized, cross-platform, timezone independent
2. **Minimum 1 Second Duration**: Practical minimum for transaction processing
3. **Maximum 24 Hour Duration**: Security and resource management

### Benefits

1. **Improved User Experience**: Faster recovery (seconds/minutes vs hours), clear expectations
2. **Technical Improvements**: Fine-grained control, reduced state bloat, better resource utilization
3. **Ecosystem Benefits**: Better wallet integration, developer tools, network reliability

## Backwards Compatibility

### Breaking Changes

1. **API Change**: `setExpiration` parameter type changes from `number` (epoch) to `number` (timestamp)
2. **Semantic Change**: Meaning of the parameter changes fundamentally

### Compatibility Strategy

**Phase 1: Dual Support (3 months)**: Support both epoch and timestamp parameters with deprecation warnings

**Phase 2: Migration Period (3 months)**: Require explicit method choice, remove automatic detection

**Phase 3: Full Transition**: Remove epoch-based API, update all documentation

## Test Cases

### Unit Tests

```typescript
// Test minimum expiration
test('rejects expiration less than 1 second', () => {
  const tx = new Transaction();
  expect(() => tx.setExpiration(Date.now() + 500)).toThrow();
});

// Test maximum expiration
test('rejects expiration more than 24 hours', () => {
  const tx = new Transaction();
  expect(() => tx.setExpiration(Date.now() + 25 * 60 * 60 * 1000)).toThrow();
});

// Test valid expiration
test('accepts expiration between 1 second and 24 hours', () => {
  const tx = new Transaction();
  expect(() => tx.setExpiration(Date.now() + 5000)).not.toThrow();
});
```

### Integration Tests

1. **Transaction Submission**: Submit transaction with 30-second expiration
2. **Object Locking**: Verify object locks during transaction processing
3. **Automatic Release**: Verify object unlocks after expiration
4. **Validator Consistency**: Test across multiple validators with time skew

## Reference Implementation

### Core Changes

```rust
// Validator-side expiration checking
struct TransactionExpiration {
    timestamp_ms: u64,  // Unix timestamp in milliseconds
}

impl TransactionExpiration {
    fn is_expired(&self, current_time_ms: u64) -> bool {
        current_time_ms >= self.timestamp_ms
    }

    fn validate(&self, current_time_ms: u64) -> Result<(), ValidationError> {
        let min_expiration = current_time_ms;
        let max_expiration = current_time_ms + 86_400_000; // 24 hours maximum

        if self.timestamp_ms < min_expiration {
            return Err(ValidationError::TooShort);
        }

        if self.timestamp_ms > max_expiration {
            return Err(ValidationError::TooLong);
        }

        Ok(())
    }
}
```

### SDK Implementation

```typescript
// TypeScript SDK implementation
class Transaction {
  private expirationTimestamp?: number;

  setExpiration(timestampMs: number): this {
    const now = Date.now();
    const min = now + 1000;
    const max = now + 24 * 60 * 60 * 1000;

    if (timestampMs < min) {
      throw new Error(`Expiration must be at least 1 second in future`);
    }

    if (timestampMs > max) {
      throw new Error(`Expiration cannot exceed 24 hours`);
    }

    this.expirationTimestamp = timestampMs;
    return this;
  }

  // Helper methods
  setExpirationSeconds(seconds: number): this {
    return this.setExpiration(Date.now() + seconds * 1000);
  }

  setExpirationMinutes(minutes: number): this {
    return this.setExpirationSeconds(minutes * 60);
  }
}
```

## Security Considerations

1. **Time Manipulation Attacks**: Mitigate with synchronized time sources and consensus
2. **Short Expiration Denial of Service**: Minimum 1-second expiration prevents this
3. **Long Expiration Resource Exhaustion**: Maximum 24-hour expiration limits impact
4. **Clock Skew Issues**: NTP synchronization with tight bounds
5. **Transaction Replay Protection**: Maintain transaction uniqueness checks

## Copyright

Copyright and related rights waived via [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).