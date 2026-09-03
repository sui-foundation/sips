|   SIP-Number |  |
|         ---: | :--- |
|        Title | Finalized State Contexts for RPC |
|  Description | A Protobuf context that carries finalized state visibility requirements across RPC operations before checkpoint processing. |
|       Author | David \<@davidrotari19\> |
|       Editor |  |
|         Type | Standard |
|     Category | Interface |
|      Created | 2026-09-03 |
| Comments-URI |  |
|       Status |  |

## Abstract

This SIP defines `FinalizedStateContext`, a bounded Protobuf value containing a
certified checkpoint anchor and a frontier of finalized transaction digests. A
supported state operation supplied with a context must either evaluate against
state that incorporates the anchor and the finalized causal closure of the
frontier, or return a structured context error without using older state.

Successful transaction execution returns a separate continuation outcome when
the client requests one. A successful continuation joins the required context
with the newly finalized transaction. Services compact contexts as checkpoints
absorb their frontier transactions.

A finalized state context establishes a lower bound on state visibility. It is
not a state snapshot, a proof of finality, an authorization token, or a source
of checkpoint ordered history.

## Motivation

Transaction finality and RPC state visibility are distinct facts on Sui. A full
node can obtain certified transaction effects and report settlement finality
before the transaction has entered a certified checkpoint. Checkpoint creation,
state synchronization, and index processing happen afterward. The transaction
is irreversible, but another state operation can still be served from a
checkpoint view that does not incorporate its effects.

The [transaction lifecycle](https://github.com/MystenLabs/sui/blob/main/docs/content/develop/transactions/transaction-lifecycle.mdx)
documents the interval between certified effects and checkpoint inclusion. The
[RPC 2.0 data consistency discussion](https://github.com/MystenLabs/sui/issues/13700)
also identifies the consequences of node affinity, lagging secondary indexes,
and checkpoint waiting. Current
[data access guidance](https://github.com/MystenLabs/sui/blob/main/docs/content/develop/accessing-data/data-serving.mdx)
recommends that gRPC clients wait or retry when a subsequent operation depends
on data that is not yet visible.

[GraphQL query scopes](https://github.com/MystenLabs/sui/blob/main/docs/content/develop/accessing-data/graphql/query-with-graphql.mdx)
can provide immediate read after write fields inside the scope attached to one
execution or simulation request. That scope does not cross RPC requests or
services, and it does not support operations that require indexed history or
live collection indexes.

Waiting for checkpoint processing is correct, but it places checkpoint and
index latency on the critical path of every dependent operation. Client caches
cannot provide a general substitute because transaction construction and
simulation can depend on objects, deleted objects, packages, dynamic children,
and other state that only the service can resolve correctly.

The missing interface guarantee is:

> If an RPC service that supports contexts returns a continuation context for a
> finalized transaction, a client can require later supported operations to
> observe state at least as new as that context without waiting for checkpoint
> visibility.

### General use cases

This guarantee is useful when a workflow cannot be expressed as one atomic
transaction or prepared completely in advance. Examples include:

* constructing a successor transaction from object references, ownership
  changes, or package information produced by a finalized predecessor;
* obtaining an external decision or a signature from another party after the
  predecessor's finalized result is known;
* finalizing independent transactions in parallel and then simulating or
  executing a transaction whose inputs depend on all of them;
* publishing or upgrading a package and immediately resolving its types and
  functions for a subsequent transaction; and
* continuing a workflow through a logical RPC service that uses load balancing
  or failover without depending on affinity to one process.

In each case, waiting for a checkpoint restores visibility but adds a separate
coordination stage after finality. The proposed context lets the client state
the visibility dependency directly and lets the service either satisfy it or
fail explicitly.

## Specification

### Terminology

A transaction is **finalized** when its effects are certified by a quorum of
the active validator committee or included in a certified checkpoint. Local
execution without either condition is not finality for this SIP.

A **checkpoint anchor** identifies certified checkpoint state that the context
has absorbed.

A transaction is **absorbed** by an anchor when the transaction is included in
that checkpoint or an earlier checkpoint on the same chain.

A **transaction dependency** is a digest in the finalized transaction's
`TransactionEffects.dependencies` field. The **causal closure** of a transaction
is the transitive closure of these dependencies, excluding transactions already
absorbed by the checkpoint anchor.

A **frontier** is a bounded set of finalized transaction digests whose effects
are required by the context but might not have been absorbed by the checkpoint
anchor. A **normalized frontier** contains only the maximal transactions under
the dependency relation and orders their digests lexicographically by canonical
digest bytes.

Context `C2` **dominates** context `C1` when every state that satisfies `C2` also
satisfies `C1`.

A **logical RPC service** is the service endpoint observed by a client. It can
contain multiple processes or nodes behind routing or load balancing.

### Context value

The API must define the following Protobuf values in a shared
`sui/rpc/v2/finalized_state.proto` file imported by each affected service:

```protobuf
message FinalizedStateCheckpoint {
  optional uint64 sequence_number = 1;
  optional string digest = 2;
}

message FinalizedStateContext {
  optional string chain_id = 1;
  optional FinalizedStateCheckpoint checkpoint_anchor = 2;
  repeated string frontier = 3;
}

message FinalizedStateRequest {
  optional FinalizedStateContext required_context = 1;
  optional bool return_context = 2;
}

message FinalizedStateContextError {
  enum Reason {
    REASON_UNKNOWN = 0;
    CONTEXT_UNSUPPORTED = 1;
    CONTEXT_WRONG_CHAIN = 2;
    CONTEXT_INVALID = 3;
    CONTEXT_NOT_FINALIZED = 4;
    CONTEXT_UNAVAILABLE = 5;
    CONTEXT_TOO_LARGE = 6;
    CONTEXT_REQUIRES_CHECKPOINT = 7;
  }

  optional Reason reason = 1;
  optional string message = 2;
}

message FinalizedStateContinuation {
  oneof result {
    FinalizedStateContext context = 1;
    FinalizedStateContextError error = 2;
  }
}

message FinalizedStateContextCapabilities {
  repeated string supported_methods = 1;
  optional uint32 max_frontier_entries = 2;
  optional uint32 max_context_bytes = 3;
  optional uint32 max_dependency_depth = 4;
  optional uint32 max_dependency_transactions = 5;
}
```

The field numbers above are local to the new messages. The existing RPC message
field numbers proposed below reflect the schema at the creation date of this
SIP and must be coordinated with the RPC API maintainers before adoption.
Implementations must use the canonical string encodings for chain, checkpoint,
and transaction digests.

The chain identifier is the canonical digest of the genesis checkpoint, matching
`GetServiceInfoResponse.chain_id`. The chain identifier, checkpoint sequence
number, and checkpoint digest are required. A service must reject a context when
the checkpoint reference is not certified for the specified chain or when the
sequence number and digest do not refer to the same checkpoint.

The frontier can contain duplicate or causally redundant transactions.
Minimality and ordering are not request validity requirements. A service must
return a normalized frontier after verifying transaction dependencies and
checkpoint inclusion.

The context carries only identifiers. The receiving service is responsible for
obtaining and verifying effects, objects, accumulator writes, and other material
needed by the requested operation. A context does not carry or replace evidence
of finality.

When verification crosses an epoch boundary, the service must verify each
certificate against the committee that was active for that certificate. An
epoch transition does not invalidate an otherwise valid context.

### State satisfaction

State `S` satisfies context `C` when all of the following conditions hold:

1. `S` belongs to the chain identified by `C`.
2. The checkpoint portion of `S` is the checkpoint anchor in `C` or one of its
   certified descendants.
3. `S` incorporates the effects of every frontier transaction in `C` and every
   transaction in their causal closure that has not been absorbed by the
   anchor.
4. Every effect incorporated beyond checkpoint state is finalized and applied
   in a valid dependency order with the same object, package, deletion,
   wrapping, ownership, and accumulator semantics as canonical execution.

A supported operation that accepts required context `C` must do exactly one of
the following:

1. Complete successfully using state that satisfies `C`.
2. Return a structured context error without evaluating the operation against
   older state.

The service must never silently fall back to a state that does not satisfy the
required context.

The state used by an operation can contain transactions newer than the context.
For example, when a frontier transaction writes an object and a later finalized
transaction writes it again, a point read can return the later object. The
context therefore provides monotonic visibility rather than repeatable reads or
snapshot isolation.

### RPC requests and responses

The initial wire contract applies to the gRPC API. A future GraphQL mapping can
carry the same semantics, but it is outside the scope of this SIP.

The initial wire contract adds a field named `finalized_state` to the following
messages. The request field has type `FinalizedStateRequest`; the response field
has type `FinalizedStateContinuation`.

| RPC message | Proposed field |
| --- | --- |
| `ExecuteTransactionRequest` | `finalized_state = 4` |
| `ExecuteTransactionResponse` | `finalized_state = 2` |
| `SimulateTransactionRequest` | `finalized_state = 5` |
| `SimulateTransactionResponse` | `finalized_state = 4` |
| `GetObjectRequest` | `finalized_state = 4` |
| `GetObjectResponse` | `finalized_state = 2` |
| `BatchGetObjectsRequest` | `finalized_state = 3` |
| `BatchGetObjectsResponse` | `finalized_state = 2` |
| `GetPackageRequest` | `finalized_state = 2` |
| `GetPackageResponse` | `finalized_state = 2` |
| `GetDatatypeRequest` | `finalized_state = 4` |
| `GetDatatypeResponse` | `finalized_state = 2` |
| `GetFunctionRequest` | `finalized_state = 4` |
| `GetFunctionResponse` | `finalized_state = 2` |

The affected messages are currently defined by the
[transaction execution service](https://github.com/MystenLabs/sui-apis/blob/main/proto/sui/rpc/v2/transaction_execution_service.proto),
[ledger service](https://github.com/MystenLabs/sui-apis/blob/main/proto/sui/rpc/v2/ledger_service.proto),
and [Move package service](https://github.com/MystenLabs/sui-apis/blob/main/proto/sui/rpc/v2/move_package_service.proto).

When `required_context` is present, a successful response must contain a
`finalized_state.context` that dominates the requirement. This acknowledgment
is required even when `return_context` is false. When no requirement is present,
`return_context` asks the service to return a lower bound on the state used by
the operation. At minimum, that context uses the service's certified checkpoint
view as its anchor. It can also include finalized effects that the service
materialized beyond that anchor. For finalized execution, the returned context
must include the new transaction.

An absent `finalized_state` response is not an acknowledgment. This rule is
required because an older Protobuf implementation can ignore an unknown request
field. The response field is control information and is not governed by an
operation's `read_mask`.

`GetServiceInfoResponse` must add
`optional FinalizedStateContextCapabilities finalized_state_contexts = 9`. The
capabilities list must use fully qualified RPC method names and advertise the
frontier, serialized size, dependency depth, and dependency transaction limits.
A service must not advertise a method that does not implement the required
failure and acknowledgment behavior. It must not issue a context that exceeds
its advertised limits. A later reduction in limits does not remove the
continuity obligation for contexts that the logical service already issued.

The scope for each operation is:

* `ExecuteTransaction` and `SimulateTransaction`, including object, package,
  child object, and accumulator resolution required by those operations;
* `GetObject` only when `version` is absent, meaning the latest visible version;
* `BatchGetObjects` as one contextual operation using its outer
  `finalized_state` field; nested `GetObjectRequest.finalized_state` fields must
  be absent; and
* `GetPackage`, `GetDatatype`, and `GetFunction` as point lookups.

For `BatchGetObjects`, context satisfaction is all or nothing. Failure to
satisfy the context fails the RPC before any result is returned. Once the
context is satisfied, ordinary results and errors for each object retain their
existing meaning. Every item must satisfy the same lower bound, but this SIP does
not require all items to come from one exact snapshot.

Reads of explicit object versions, `ListPackageVersions`, collection reads,
pagination, and methods ordered by checkpoint are outside the initial scope.

### Transaction execution

An execution request can ask the service to return a continuation context. The
service must validate the required context, retrieve and verify its causal
closure, materialize a satisfying state, and reserve the resources needed for
continuation before it submits the new transaction for execution.

After transaction `T` reaches finality, including final execution with an error
status, the returned continuation context must satisfy both the input context
and `T`. The service can remove frontier entries that are causal ancestors of
other entries or that have entered the returned checkpoint anchor.

A logical RPC service that returns continuation context `C` must remain able to
honor `C` until its frontier has been absorbed into a certified checkpoint
available to that service. It must not return `CONTEXT_UNAVAILABLE` during that
period solely because a request reached another backend or because a local cache
was evicted. Routing, shared storage, effect retrieval, and durable
materialization are implementation choices. A complete service outage is outside
this semantic guarantee.

If the service cannot reserve the resources required to provide continuation,
it must reject the context request before transaction submission. This is an
RPC failure carrying a structured context error instead of an execution
response.

If the transaction nevertheless becomes final before continuation
materialization fails, the service must return the finalized transaction result
and set `finalized_state.error` in the response. It must not use an RPC error in
place of the response, represent the finalized transaction as an execution
rejection, or invite submission under another digest. The transaction outcome
and continuation outcome are independent in this case after finality.

Execution requests that do not request a context retain their existing
behavior.

### Simulation and point reads

Simulation and point reads supplied with context `C` must resolve state from a
view that satisfies `C`. This includes honoring deletion and wrapping effects;
the service must not resurrect an older object from its checkpoint store when a
frontier transaction removed it.

Simulation remains a prediction against the state selected by the service. A
context prevents simulation against state older than `C`, but it does not
prevent newer state from changing the simulation result.

For a point read, ordinary absence can be returned only after context
satisfaction. In particular, a service must distinguish an object that is
absent in satisfying state from an inability to retrieve the context needed to
determine its state. If ordinary absence is represented by a gRPC `NOT_FOUND`
status rather than an empty response, the status details must contain a
`FinalizedStateContinuation.context` that acknowledges the required context.
This acknowledgment is not a context error.

Package point lookups must include packages published by the context. Package
version enumeration remains checkpoint dependent and is outside scope.

### Context availability and portability

The issuer guarantee applies to the logical service that returned a context,
including all backends presented as that service. It does not require affinity
to the individual process that executed the transaction.

A different logical service can satisfy the same context by independently
retrieving and verifying its checkpoint and finalized effects. If it cannot do
so, it must return `CONTEXT_UNAVAILABLE`; it must not claim that the context was
honored. This SIP standardizes the transferable visibility requirement and
failure semantics, but it does not standardize effects retrieval between
providers or guarantee that every provider can satisfy every context.

This distinction makes the context portable as a request value without treating
availability as a finality proof or requiring providers to trust one another.

### Joining contexts

Contexts from parallel workflows can be joined when they identify the same
chain. A client or SDK can construct an unverified join by:

1. Rejecting the join when the chain identifiers differ.
2. Selecting the anchor with the greater sequence number. If both anchors have
   the same sequence number but different digests, rejecting the join.
3. Taking the union of both frontiers without discarding entries that might have
   been absorbed by the selected anchor.

The resulting context contains only the selected anchor and the union frontier;
the original anchors do not need to cross the API boundary. Before honoring the
result, a service must:

1. Verify that the selected anchor is a certified checkpoint for the specified
   chain.
2. Obtain and verify the finality of every frontier transaction.
3. Remove transactions verified as absorbed by the selected anchor.
4. Recursively follow `TransactionEffects.dependencies` for every remaining
   transaction until reaching transactions absorbed by the anchor.
5. Reject the context if the effects cannot compose from the selected anchor in
   dependency order with valid object versions and ownership transitions.
6. Remove a frontier transaction when it is a transitive dependency of another
   retained frontier transaction, then sort the remaining digests
   lexicographically by canonical digest bytes.

The verified result uses the selected anchor and normalized frontier. Client
construction is not authoritative. A distinct join RPC is not required.

If the joined context exceeds advertised bounds, the service must return a
structured size or resource error. It must not discard frontier entries.

### Context compaction

A service can return a normalized context with a newer certified checkpoint
anchor. It can remove a frontier entry only after verifying that the
transaction is included at or before the new anchor, or that the transaction is
a causal ancestor of another retained frontier entry.

After removing absorbed transactions, the service must recompute the causal
closure against the newer anchor, remove frontier entries that are transitive
dependencies of retained entries, and sort the normalized frontier by canonical
digest bytes. An empty frontier is a valid context containing only a checkpoint
anchor.

Compaction is service controlled. A client supplied checkpoint reference is a
requirement to verify, not authority to discard frontier transactions. A
distinct compaction RPC is not required.

### Operations that require checkpoints

This SIP does not assign checkpoint positions to transactions before they enter
a checkpoint. It does not synthesize:

* checkpoint sequence numbers or timestamps;
* transaction positions within checkpoints;
* checkpoint ordered transaction or event history;
* stable pagination cursors for indexed collections;
* complete owned object, balance, or dynamic field collection indexes.

An operation that requires this information must wait for checkpoint
visibility or return a structured error indicating that checkpoint state is
required. Execution and simulation responses can return transaction effects,
events, and changed objects without claiming a position in checkpoint ordered
history. The `checkpoint`, `timestamp`, and `transaction_index` fields of an
`ExecutedTransaction` must remain absent until the transaction enters a
checkpoint.

### Errors

Context failures must be distinguishable from transaction execution status and
ordinary object absence. Clients must be able to recover the structured reason
without parsing an error message. Before transaction submission and for all
operations other than execution, the reasons and recommended gRPC mappings are:

* `CONTEXT_UNSUPPORTED` maps to `UNIMPLEMENTED`. The service or method does not
  implement contexts.
* `CONTEXT_WRONG_CHAIN` maps to `INVALID_ARGUMENT`. The context identifies
  another chain.
* `CONTEXT_INVALID` maps to `INVALID_ARGUMENT`. The context is malformed or
  contains inconsistent verified data.
* `CONTEXT_NOT_FINALIZED` maps to `FAILED_PRECONDITION`. A referenced
  transaction was found, but finality could not be established.
* `CONTEXT_UNAVAILABLE` maps to `UNAVAILABLE`. Required verification or state
  material could not be retrieved.
* `CONTEXT_TOO_LARGE` maps to `RESOURCE_EXHAUSTED`. An advertised size or
  traversal limit was exceeded.
* `CONTEXT_REQUIRES_CHECKPOINT` maps to `FAILED_PRECONDITION`. The requested
  operation requires information derived from a checkpoint.

The structured `FinalizedStateContextError` must be attached as error detail.
After transaction finality, the same reason appears inside the successful
execution response as described above rather than as a transport error.

## Rationale

### Checkpoint anchor and transaction frontier

A single causal parent is sufficient for a linear workflow but cannot express
the join of independent finalized branches. A checkpoint anchor plus a frontier
set forms a compact lower bound for both linear and parallel workflows.
The anchor also provides a natural compaction point as checkpoint processing
catches up.

The frontier carries transaction digests rather than full effects or objects so
that it remains compact and does not make client supplied data authoritative.
Each service independently verifies the finality and material needed for the
operation.

### Protobuf rather than transport metadata

The context changes request and response semantics and therefore belongs in the
typed RPC schema. Protobuf fields provide generated client support, explicit
capability acknowledgment, schema documentation, and consistent behavior
through gateways. Transport metadata can be useful for experiments but is not a
suitable public contract.

### Lower bound rather than snapshot

The purpose of the context is to prevent state from moving backward relative to
known finality. Requiring an exact snapshot before checkpoint inclusion would
prevent the service from using newer checkpoint state, require substantially
more retained data, and imply ordering that does not exist before checkpoint
formation.

### Explicit failure

A service that did not issue a context might be unable to retrieve a frontier
transaction because of retention, overload, or lack of feature support. An
explicit failure preserves correctness and permits the client to select another
service or wait for checkpoint visibility. Silent fallback would make the
consistency property unverifiable. An issuing logical service instead assumes
the continuity obligation described in the specification.

### Alternatives

Waiting for checkpoint visibility is the universal fallback and remains
necessary for operations ordered by checkpoint. It is not equivalent to this
proposal because it adds checkpoint propagation and processing to every
dependent operation after transaction finality.

Affinity to one process can expose recently executed effects, but it is not a
consistency contract visible to clients and does not survive routing, failover,
or independent service implementations. An opaque handle issued by a service
would make that affinity explicit, but it would prevent clients from joining
contexts and would not carry meaningful requirements to another service.

Carrying full certified effects would improve independent retrieval, but it
would make contexts substantially larger and would duplicate validation
material in every dependent request. This SIP carries digests and leaves effect
retrieval to the service. A future extension can define a transferable effects
proof without changing the lower bound semantics.

A Programmable Transaction Block is preferable when all dependent commands can
be constructed and authorized atomically. It does not cover a successor that
depends on an external decision, a later signature, or information learned only
after the predecessor finalizes.

GraphQL scopes attached to execution are preferable when all required fields
can be selected in the same request. They do not provide a context that can
continue across separate requests or services.

[SIP-19](sip-19.md) soft bundles can coordinate multiple transactions that are
known in advance. They do not express a successor that must be constructed from
the finalized result of its predecessor.

### Why this is an interface contract

Retained effects, delta chains, caches, routing, and checkpoint waiting are all
possible materialization strategies. None lets a client state or verify the
visibility requirement unless the RPC interface carries it. This SIP therefore
standardizes the context, acknowledgment, and failure behavior while leaving
materialization internal to each service.

## Open Questions

The following choices should be resolved with RPC implementers during the Draft
stage:

1. Whether a later extension should standardize retrieval of certified effects
   between independent providers, or retain portability between providers on a
   best effort basis.
2. Whether the first implementation should include all three Move package point
   methods or begin with execution, simulation, and object point reads only.
3. Whether capability discovery needs an advertised minimum retention interval
   from the issuer after checkpoint absorption, in addition to the mandatory
   period before absorption.
4. Whether the proposed field numbers conflict with RPC schema work that lands
   before this SIP is accepted.

## Backwards Compatibility

The proposal is additive. Clients that do not request finalized state contexts
and services that do not implement them retain existing behavior.

New clients must require positive response acknowledgment. This is necessary
because an older protobuf service can ignore an unknown request field. A client
must not interpret an ordinary response with no returned context as proof that
its context was honored.

Services can introduce support one RPC method at a time, but service information
must identify the supported methods and applicable limits. A method that does
not support contexts must return `CONTEXT_UNSUPPORTED` before performing an
operation that the client required to be context aware.

## Security Considerations

A finalized state context is not an authorization token and must not grant
access that the underlying RPC operation would otherwise deny. It also is not a
proof of finality. Services must independently verify the chain, checkpoint,
transaction finality, effects, and dependency relations.

Untrusted contexts can cause storage, network, CPU, and memory amplification.
Implementations must bound frontier count, serialized size, causal traversal,
effect retrieval, concurrent materialization, and retained state. Limits must
be checked before expensive retrieval whenever possible. Unknown or
unavailable digests must not cause unlimited validator or peer queries.

Implementations must preserve tombstones and ownership changes when combining
frontier effects with checkpoint state. Falling back to an older live object
after a finalized deletion, wrap, or ownership change violates the central
invariant and can lead to incorrect transaction construction or simulation.

The service must distinguish failure before transaction submission from
failure after transaction finality. Reporting a final transaction as rejected
can cause clients to create another transaction and produce unintended repeated
effects.

Contexts from different chains or incompatible checkpoint anchors must be
rejected. Implementations must not trust client requested compaction, because
discarding a frontier entry before checkpoint absorption can reintroduce stale
state.

## Copyright

This document is licensed under [CC0 1.0](../LICENSE.md).
