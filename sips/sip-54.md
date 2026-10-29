|         ---: | :--- |
|        Title | One-Click Trading |
|  Description | Extensions to the Wallet Standard feature set on Sui to provide auto-signing (one-click trading) functionality. |
|       Author | Kevin \<github@aftermath.finance, @admin-aftermath\>, Aftermath Finance \<[aftermath.finance](https://aftermath.finance/)\> |
|       Editor | |
|         Type | Standard |
|     Category | Application [Wallet Standard] |
|      Created | TODO |
| Comments-URI | N/A |
|       Status | Idea |
|     Requires | N/A |

## Abstract

This SIP specifies extensions to the Wallet Standard to enable one-click trading (1CT) functionality on Sui. The proposed changes allow wallets to auto-sign transactions based on *user-defined* parameters, significantly improving the trading experience on Sui by reducing the friction and latency that arises with sign transaction popups.

> As the Sui wallet standard will continue to evolve over time, a snapshot of the `MystenLabs/ts-sdks` repo will be used when referencing the Sui wallet standard code. This SIP uses the latest stable version of the standard: `v0.13.26`.<sup>[1](https://github.com/MystenLabs/ts-sdks/tree/d97548c24aedfe2c9fcb55fa5365c6cae5413fb1/packages/wallet-standard)</sup>

## Scope

This SIP outlines the general functionality that is required to enable granularly-defined auto-signing functionality on Sui. With that said, the sole purpose of this proposal is to initiate a discussion around one-click trading support rather than prescribe a single implementation.

## Background

**Wallet Standard.** The Wallet Standard is a set of interfaces and conventions designed to improve the user experience and developer experience of wallets and applications for any blockchain.<sup>[2](https://github.com/wallet-standard/wallet-standard/)</sup> By defining consistent methods for common wallet functionality such as connecting, signing transactions, and managing accounts, the Wallet Standard eliminates the need for developers to create custom integrations for each wallet provider. This approach improves interoperability between dApps and wallets, and significantly enhances the user experience by enabling a more consistent "Sign in" flow across different blockchains.

**Sui Extensions.** Different chains can add their own extensions to the wallet standard to support their own chain-specific features or improvements. For example, Sui has added the `sui:signAndExecuteTransaction` extension, which prompts the user to sign a transaction and then submits the transaction for execution.

Throughout this SIP, I will use the term Sui wallet standard to refer to the Wallet Standard with the Sui extensions. The Sui wallet standard is thus a superset of the Wallet Standard and defines how dApps discover and interact with Sui-based wallets, as well as the set of features a Sui wallet must implement. A full list of the Sui extensions can be found in the Sui wallet standard [docs](https://docs.sui.io/standards/wallet-standard#implementing-features).<sup>[3](https://docs.sui.io/standards/wallet-standard#implementing-features)</sup>

**One-Click Trading.** One-click trading allows users to auto accept transactions, instead of having to individually approve each transaction they wish to execute. 1CT emulates the UX of traditional (e.g., Web2) applications and is a commonly adopted feature in many DeFi applications, although it is has a broader use case than just DeFi.

**Object-Centric Data Model.** Sui utilizes an object-centric data model meaning that everything on Sui is an object. For example, an address on Sui holding 10 SUI might in fact have 5 individual `Coin<SUI>` objects that comprise the total 10 SUI.

The distinction between an address' total balance and the underlying `Coin` objects that comprise the total balance is very important given the context of this SIP.

## Motivation

**User Experience.** Currently, every transaction on Sui that utilizes a browser extension wallet requires explicit user approval through a wallet popup. This requirement introduces two primary pain points that can be particularly impactful for those performing multiple consecutive transactions or those operating in latency-sensitive verticals where the delay incurred by having to click "Approve Transaction" is not marginal.

&nbsp;&nbsp;&nbsp;&nbsp; For example, this delay can lead to missed opportunities in fast-moving markets or increase the chance of slippage errors in DEX aggregator routes that rely on point-in-time snapshots of on-chain state to achieve their desired output.

1CT typically involves pre-approving transactions that originate from a specified origin dApp. By doing so, 1CT outright eliminates the aforementioned pain points that are associated with the current UX of requiring explicit user approval for each transaction.

**Familiarity.** One-click trading helps bridge the UX gap between Sui-based applications and their traditional, off-chain counterparts. This enhanced UX reduces the barrier of entry for non-web3-native users, making Sui more accessible to mainstream users while still maintaining the benefits of inherent to Web3.

**Customization.** Given Sui's object-centric data model, it is unlikely you want to grant auto-approval for all objects owned by your address. Depending on (1) the type of actions you are performing, (2) the dApps you are interacting with, (3) the total duration of your current session, and (4) your risk profile, you will likely desire pre-approval for only a subset of your objects. This SIP aims to support a level of granularity that allows users to customize their auto-approval settings based on their exact preferences.

Different preferences of 1CT come with their own security assumptions, the security of one-click trading are further discussed in the **Security Considerations** section.

## Prerequisites

There are no prerequisites for this SIP.

## Specification

The Sui Wallet Standard will be be extended to support auto-signing of transactions based on multiple *user-defined* filters, any of which can independently approve a transaction. Auto-signing filters are defined by a set of constraints, including:
 1. Expiry timestamp, after which auto-signing based on this filter is disabled.
 2. Maximum number of transactions to auto-sign, after which auto-signing based on this filter is disabled.
 3. Object filters (e.g., object types, object IDs, per-type limits), which can be used to express very-granular, object-based restrictions for auto-signing.
 4. Move call filters (e.g., allowed packages, modules, and functions), which can be used to restrict the functionality to auto-sign.
 5. Origin-based filters, which can be used to restrict auto-signing to transactions originating from specific dApps.
Transactions are approved if they match *any* of the active filters (OR logic), while criteria within a single filter use AND logic.

Secondary functions will be added to the `autoSignTransaction` namespace to allow querying if a transaction can be auto-signed, the addition and removal of auto-signing filters, the retrieval of the current auto-signing filters, and the disabling of all auto-signing for the current address.

Adding a new auto-sign filter **must** be signed off by the user through a flow akin to `sui:signPersonalMessage`.

**Optional.** There are additional constraints that are left out of this SIP, as they rely on information external to the wallet, but they can be utilized for more expressive auto-signing filtering:
 1. Price-based filters (e.g., maximum transaction value, maximum cumulative value), which can be used to restrict auto-signing based on the maximum value of a singular transaction or a series of transactions.
&nbsp;&nbsp;&nbsp;&nbsp; '-> It is worth noting that a maximum culumulative price-based filter can be achieved through the use of object filters; for exmple, a $100 SUI limit can be achieved through joining and spliting `Coin<SUI>` objects to produce a `Coin<SUI>` object with value equivalent to $100 and filtering on its object ID.

## Rationale

As more complex dApps are built on Sui, the "Sign transaction" popup becomes an increasingly significant bottleneck for users, particularly in scenarios requiring rapid (e.g., gaming) or latency-sensitive (e.g., DeFi) interactions. The addition of one-click trading is a significant step towards eliminating this friction and improving the user experience across the network.

It is important to reiterate that not all users will have equal risk tolerances when it comes to 1CT. The ability to customize the auto-approval settings based on the user's exact preferences is a key feature of this SIP. Sui's object-centric data model provides a unique opportunity to implement fine-grained security controls: allowing users to specify pre-approval for a set of object types or IDs if they so desire.

It is also important to allow users to set multiple filters, each with their own set of constraints. This gives users the flexibility to create simple, permissive filters for dApps they trust while maintaining stricter controls for others.

## Backwards Compatibility

This SIP presents no issues with backwards compatibility.

## Reference Implementation

Typescript is not my language of choice; I welcome any suggestions or improvements to make the following reference implementation more idiomatic. Furthermore, the point of this reference implementation is primarily to provide an example on the underlying features that make up the one-click trading functionality.

The relevant changes to provide 1CT are split between changes to the Sui extension of the Wallet Standard and the actual implementation; these are detailed below.

### i. Wallet Standard Extensions

The following features should be added to the Wallet Standard:
- `sui:autoSignTransaction`
- `sui:autoSignAndExecuteTransaction`
- `sui:autoSignPersonalMessage`
- `sui:canAutoSignTransaction` (optional)
- `sui:getAutoSignTransactionFilter`
- `sui:addAutoSignTransactionFilter`
- `sui:removeAutoSignTransactionFilter`
- `sui:disableAllAutoSignTransactionFilters` (optional)

### ii. Sui Wallet Standard

The `ts-sdks` reference implementation should be updated to include the following changes:

### iia. `suiAutoSignTransaction`

```typescript
/** The latest API version of the autoSignTransaction API. */
export type SuiAutoSignTransactionVersion = '1.0.0';

/**
 * A Wallet Standard feature for auto-signing transactions based on user-defined parameters.
 */
export type SuiAutoSignTransaction = {
  /** Namespace for the feature. */
  'sui:autoSignTransaction': {
    /** Version of the feature API. */
    version: SuiAutoSignTransactionVersion;

    /** Auto sign a transaction if it meets the bounds set by the active address. */
    autoSignTransaction: SuiAutoSignTransactionMethod;
  };
};

export type SuiAutoSignTransactionMethod = (
	input: SuiAutoSignTransactionInput,
) => Promise<SuiAutoSignTransactionOutput>;

/** Input for auto signing transactions. */
export interface SuiAutoSignTransactionInput extends SuiSignTransactionInput {}

/** Output for auto signing transactions. */
export interface SuiAutoSignTransactionOutput extends SuiSignTransactionOutput {}
```

### iib. `suiAutoSignAndExecuteTransaction`

```typescript
/** The latest API version of the autoSignAndExecuteTransaction API. */
export type SuiAutoSignAndExecuteTransactionVersion = '1.0.0';

/**
 * A Wallet Standard feature for auto-signing transactions based on user-defined parameters.
 */
export type SuiAutoSignAndExecuteTransaction = {
  /** Namespace for the feature. */
  'sui:autoSignAndExecuteTransaction': {
    /** Version of the feature API. */
    version: SuiAutoSignAndExecuteTransactionVersion;

    /**
     * Auto sign a transaction, if it meets the bounds set by the active address,
     * and execute it.
     */
    autoSignTransaction: SuiAutoSignAndExecuteTransactionMethod;
  };
};

export type SuiAutoSignAndExecuteTransactionMethod = (
	input: SuiAutoSignAndExecuteTransactionInput,
) => Promise<SuiAutoSignAndExecuteTransactionOutput>;

/** Input for auto signing and sending transactions. */
export interface SuiAutoSignAndExecuteTransactionInput extends SuiSignTransactionInput {}

/** Output of auto signing and sending transactions. */
export interface SuiAutoSignAndExecuteTransactionOutput extends SignedTransaction {
	digest: string;
	/** Transaction effects as base64 encoded bcs. */
	effects: string;
}
```

### iic. `suiAutoSignPersonalMessage`

```typescript
/** The latest API version of the autoAutoSignPersonalMessage API. */
export type SuiAutoSignPersonalMessageVersion = '1.0.0';

/**
 * A Wallet Standard feature for auto signing a personal message, and returning the
 * message bytes that were signed, and message signature.
 */
export type SuiAutoSignPersonalMessageFeature = {
	/** Namespace for the feature. */
	'sui:autoAutoSignPersonalMessage': {
		/** Version of the feature API. */
		version: SuiAutoSignPersonalMessageVersion;
		autoAutoSignPersonalMessage: SuiAutoSignPersonalMessageMethod;
	};
};

export type SuiAutoSignPersonalMessageMethod = (
	input: SuiAutoSignPersonalMessageInput,
) => Promise<SuiAutoSignPersonalMessageOutput>;

/** Input for auto signing personal messages. */
export interface SuiAutoSignPersonalMessageInput {
	message: Uint8Array;
	account: WalletAccount;
}

/** Output of auto signing personal messages. */
export interface SuiAutoSignPersonalMessageOutput extends AutoSignedPersonalMessage {}

export interface AutoSignedPersonalMessage {
	/** Base64 encoded message bytes */
	bytes: string;
	/** Base64 encoded signature */
	signature: string;
}```


### iid. [Optional] `suiCanAutoSignTransaction`

```typescript
/** The latest API version of the canAutoSignTransaction API. */
export type SuiCanAutoSignTransactionVersion = '1.0.0';

/**
 * A Wallet Standard feature for querying if a specified transaction meets an accounts
 * pre-defined filters for auto approval.
 */
export type SuiCanAutoSignTransaction = {
  /** Namespace for the feature. */
  'sui:canAutoSignTransaction': {
    /** Version of the feature API. */
    version: SuiCanAutoSignTransactionVersion;
    canAutoSignTransaction: SuiCanAutoSignTransactionMethod;
  };
};

export type SuiCanAutoSignTransactionMethod = (
	input: SuiAutoSignTransactionInput,
) => Promise<boolean>;
```

### iie. `suiGetAutoSignTransactionFilter`

```typescript
/** The latest API version of the getAutoSignTransaction API. */
export type SuiGetAutoSignTransactionVersion = '1.0.0';

/**
 * A Wallet Standard feature for querying an accounts active auto-signing filters.
 */
export type SuiGetAutoSignTransaction = {
  /** Namespace for the feature. */
  'sui:getAutoSignTransaction': {
    /** Version of the feature API. */
    version: SuiGetAutoSignTransactionVersion;
    getAutoSignTransactionFilters: SuiGetAutoSignTransactionFiltersMethod;
  };
};

export type SuiGetAutoSignTransactionFiltersMethod = (account?: WalletAccount)
    => Promise<AutoSignTransactionFilterInfo[]>;

/** Represents limits for a specific object type in auto-signing transactions. */
export interface ObjectTypeLimit {
    /** The fully qualified type string (e.g. "0x2::example::Type") */
    readonly type: string;

    /** Maximum number of objects of this type that can be used in a single transaction */
    readonly maxObjects?: number;

    /** Maximum number of objects of this type that can be used across all transactions */
    readonly maxCumulativeObjects?: number;
}

/**
 * Coin-specific limits for auto-signing transactions. Used to restrict both per-transaction and
 * cumulative coin values that can be auto-signed.
 */
export interface CoinTypeLimit extends ObjectTypeLimit {
    /** Maximum total coin value that can be used in a single transaction */
    readonly maxValue?: bigint;

    /** Maximum cumulative coin value that can be used across all transactions */
    readonly maxCumulativeValue?: bigint;
}

/**
 * Configuration for filtering which input objects can be auto-signed.
 * If filters undefined or empty, all objects will be auto-signed.
 */
export interface InputFilters {
    /** List of specific object IDs that can be auto-signed. */
    readonly objectIds?: readonly string[];

    /** Granular limits for object types */
    readonly objectTypeLimits?: ReadOnly<{
        /**
         * Limits for coin objects, allowing restrictions on type, quantity, and value.
         * Applies to both single transactions and cumulative usage.
         */
        coins?: CoinTypeLimit;

        /**
         * Limits for non-coin objects, allowing restrictions on both type and quantity.
         * Applies to both single transactions and cumulative usage.
         */
        objects?: ObjectTypeLimit;
    }>;
}

/** Configuration for filtering which modules and their functions can be auto-signed. */
export interface MoveModuleConfig {
    /** Name of the Move module */
    readonly module: string;
    /**
     * List of function names that can be auto-signed within this module.
     * If undefined, all functions in `module` can be auto-signed.
     */
    readonly functions?: readonly string[];
}

/** Configuration for filtering which packages and their modules can be auto-signed. */
export interface MovePackageConfig {
    /** Address of the Move package (e.g. "0xpackage") */
    readonly package: string;
    /**
     * List of module configurations within this package.
     * If undefined, all modules in `package` can be auto-signed.
     */
    readonly modules?: readonly MoveModuleConfig[];
}

/**
 * Configuration for filtering which Move calls can be auto-signed.
 * Provides hierarchical filtering from package level down to specific functions.
 *
 * The filtering is hierarchical:
 * - If packages is undefined, all Move calls can be auto-signed
 * - If a package's modules is undefined, all modules in that package can be auto-signed
 * - If a module's functions is undefined, all functions in that module can be auto-signed
 */
export interface MoveCallFilters {
    /** List of Move packages that can be auto-signed */
    readonly packages?: readonly MovePackageConfig[];
}

/**
 * Configuration for an auto-signing filter. Multiple filters can be active simultaneously,
 * each with its own constraints. Undefined fields are treated as wildcards (no restrictions).
 */
export interface AutoSignTransactionFilter {
    /** The account this filter applies to */
    readonly account: WalletAccount;

    /** Human-readable name for the filter. Used in wallet UI for filter management. */
    readonly name?: string;

    /**
     * Unix timestamp when this filter expires. If undefined, filter remains active until
     * wallet disconnection
     */
    readonly expiry?: number;

    /**
     * Maximum number of transactions this filter can auto-sign. If undefined, no limit is
     * assumed.
     */
    readonly maxTransactions?: number;

    /** Object-based filters for auto-signing. */
    readonly inputs?: InputFilters;

    /** Move call filters for auto-signing. */
    readonly moveCalls?: MoveCallFilters;
}

/** Information about an active auto-sign filter including its current state. */
export interface AutoSignTransactionFilterInfo {
    /** Unique identifier for this filter */
    id: string;

    /** The filter definition */
    filter: AutoSignTransactionFilter;

    /** Current state/usage tracking for this filter */
    state: {
        /** Unix timestamp when this filter was created */
        created: number;

        /** Number of transactions auto-signed using this filter */
        transactionsApproved: number;

        /** Per-type object usage tracking */
        objectUsage?: {
            /** Tracks cumulative usage of coin types */
            coins?: {
                [type: string]: {
                    objectsUsed: number;
                    valueUsed: bigint;
                };
            };

            /** Tracks cumulative usage of non-coin objects */
            objects?: {
                [type: string]: {
                    objectsUsed: number;
                };
            };
        };
    };
}
```

### iif. `suiAddAutoSignTransactionFilter`

```typescript
/** The latest API version of the addAutoSignTransaction API. */
export type SuiAddAutoSignTransactionVersion = '1.0.0';

/**
 * A Wallet Standard feature configuring an address' auto-signing filters.
 */
export type SuiAddAutoSignTransaction = {
  /** Namespace for the feature. */
  'sui:addAutoSignTransaction': {
    /** Version of the feature API. */
    version: SuiAddAutoSignTransactionVersion;
    addAutoSignTransactionFilter: SuiAddAutoSignTransactionFilterMethod;
  };
};

export type SuiAddAutoSignTransactionFilterMethod = (filter: AutoSignTransactionFilter)
    => Promise<string>; // Returns filterId
```

### iig. `suiRemoveAutoSignTransactionFilter`

```typescript
/** The latest API version of the removeAutoSignTransaction API. */
export type SuiRemoveAutoSignTransactionVersion = '1.0.0';

/**
 * A Wallet Standard feature to allow removal of an removeress' specific auto-signing filter.
 */
export type SuiRemoveAutoSignTransaction = {
  /** Namespace for the feature. */
  'sui:removeAutoSignTransaction': {
    /** Version of the feature API. */
    version: SuiRemoveAutoSignTransactionVersion;
    removeAutoSignTransactionFilter: SuiRemoveAutoSignTransactionFilterMethod;
  };
};

export type SuiRemoveAutoSignTransactionFilterMethod = (filterId: string) => Promise<void>;
```

### iih. [Optional] `suiDisableAllAutoSignTransactionFilter`

```typescript
/** The latest API version of the disableAllAutoSignTransaction API. */
export type SuiDisableAllAutoSignTransactionVersion = '1.0.0';

/**
 * A Wallet Standard feature to disable auto-signing for the current address.
 */
export type SuiDisableAllAutoSignTransaction = {
  /** Namespace for the feature. */
  'sui:disableAllAutoSignTransaction': {
    /** Version of the feature API. */
    version: SuiDisableAllAutoSignTransactionVersion;
    disableAllAutoSignTransactionFilters: SuiDisableAllAutoSigntransactionFiltersMethod;
  };
};

export type SuiDisableAllAutoSignTransactionFilterMethod = (filterId: string) => Promise<void>;
```

### iii. `wallet.ts`

The `signAndExecuteTransaction` and `signTransaction` functions should be updated to include auto-signing logic:

```typescript
export async function signAndExecuteTransaction(
	wallet: WalletWithFeatures<Partial<SuiWalletFeatures>>,
	input: SuiSignAndExecuteTransactionInput,
) {
    if (
        wallet.features['sui:autoSignTransaction']
          && wallet.features['sui:autoSignTransaction'].canAutoSignTransaction(input)
    ) {
        return wallet.features['sui:autoSignTransaction'].autoSignAndExecuteTransaction(input);
    }

    ...
}

export async function signTransaction(
	wallet: WalletWithFeatures<Partial<SuiWalletFeatures>>,
	input: SuiSignTransactionInput,
) {
    if (
        wallet.features['sui:autoSignTransaction']
          && wallet.features['sui:autoSignTransaction'].canAutoSignTransaction(input)
    ) {
        return wallet.features['sui:autoSignTransaction'].autoSignTransaction(input);
    }

    ...
}
```

## Rollout

The rollout should be conducted in multiple phases to ensure users and dApps properly implement it and to allow users the chance to fully understand this feature before utilizing it.

**Phase 1.** The first phase should involve adding the new features as optional extensions to the Sui Wallet Standard on **Sui Testnet** only. This phase should also include the release of a reference implementation and documentation to guide wallet developers and dApps in integrating the new functionality.

**Phase 2.** This phase involves enabling the feature as a optional extension on **Sui Mainnet**.

**Phase 3.** This phase involves setting the new Sui wallet features as required on **Sui Testnet**.

**Phase 4.** The final phase should involve making the features required on **Sui Mainnet** and should only occur after sufficient time has elapsed since **Phase 1**. The window between **Phase 1** and **Phase 4** should be long enough for wallet providers to have their implementations be audited. This window also provides dApps with the opportunity to integrate and test their applications with the auto-signing feature.

## Security Considerations

The manual approval of transactions is often the last line of defense against malicious transactions, ensuring that users can review each transaction before it is executed. The introduction of one-click trading removes this step and thus the security implications around one-click trading should be understood by all.

To combat this, this SIP proposes a modular, filtering-based approach to auto-signing so users can customize their auto-approval settings based on their exact preferences, and ideally nothing more. This creates a spectrum of security assumptions that users can choose from, ranging from very permissive (undefined filters) to very restrictive (objectId- and function-based filtering).

**Educating Users.** First and foremost, an ecosystem-wide effort should be made to educate users on the risks of enabling auto-signing features and the importance of setting appropriate filters:
 - Wallets should clearly communicate the risks of enabling auto-signing to users within their UI.
 - dApps that take advantage of auto-signing features should provide clear guidance on setting appropriate limits and durations through their docs.

**Wallets.** There are many things a wallet should consider when implementing this feature:
 - Wallets need to implement robust validation to ensure that transactions do not exceed the limits set by users. This includes validating the transaction parameters against the active filters and ensuring that the transaction does not exceed the maximum number of transactions or the expiry timestamp set by the user.
 - Wallets should provide a clear and intuitive interface for users to configure their auto-signing filters.
 - Auto-signed transactions should be clearly marked in the in-wallet transaction history.

**Audit Requirements.** Wallets should undergo security audits to ensure that their implementation is secure.

**dApps.** dApps should provide wallets / users with prebuilt filters based around their dApp's functionality. For example, an AMM should provide a filter that auto-approves transactions for their package addresses. This places the burden of filter construction on the dApp, eliminating the need for a user to do so themselves.

## References

1. [[MystenLabs/ts-sdks] 0.13.26](https://github.com/MystenLabs/ts-sdks/tree/d97548c24aedfe2c9fcb55fa5365c6cae5413fb1/packages/wallet-standard)
2. [[Wallet Standard] Wallet Standard](https://github.com/wallet-standard/wallet-standard/)
3. [[Sui Docs] Wallet Standard](https://docs.sui.io/standards/wallet-standard#implementing-features)
4. [[MystenLabs/ts-sdks] Wallet Standard](https://github.com/MystenLabs/ts-sdks/tree/main/packages/wallet-standard)

## Copyright

[CC0 1.0](../LICENSE.md).
