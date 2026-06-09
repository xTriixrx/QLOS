# QLOS Project Direction

QLOS is a Common Lisp project for building a hardware-independent quantum
compiler and execution stack. Its intended role is closer to an LLVM-style
compiler infrastructure paired with a runtime than to a single simulator,
language, or hardware SDK. The project begins with a correct, observable, and
performant simulator, then adds a stable intermediate representation, reusable
compiler passes, backend contracts, and runtime services as those layers become
useful.

The long-term objective is:

> One compiler and runtime foundation for describing, transforming, lowering,
> simulating, and executing quantum programs across different targets.

This document describes project direction rather than the currently supported
API. See the [project README](../README.md) for installation and usage.

## An LLVM-Inspired Role

QLOS is intended to occupy a role for quantum programs analogous to the role
LLVM occupies for classical compiler toolchains:

- Frontends translate user-facing languages or DSLs into a common intermediate
  representation.
- Validation and analysis passes establish that programs are well formed.
- Transformation passes optimize, decompose, and lower operations.
- Target descriptions expose backend capabilities and constraints.
- Backend adapters translate lowered programs into simulator operations,
  interchange formats, provider APIs, or hardware-native instructions.
- Runtime services manage execution, shots, jobs, and normalized results.

The analogy is architectural, not a claim of compatibility or equivalent
scope. QLOS does not currently use LLVM IR, replace LLVM, or attempt to compile
general-purpose classical programs. It applies similar separation of concerns
to quantum circuits and their execution lifecycle.

The long-term product is therefore not only a quantum simulator. The simulator
is the first executable backend and the proving ground for the intermediate
representation, pass interfaces, backend protocol, and runtime semantics.

## Current Foundation

The repository currently contains:

- An ideal pure-state state-vector simulator.
- Specialized complex double-float amplitude storage.
- In-place `X`, `H`, `Z`, `S`, `T`, and `CNOT` gate kernels.
- Computational-basis measurement with state collapse.
- A circuit representation and Lisp circuit DSL.
- Circuit execution, correctness tests, and a benchmark workload.

This is the first backend, not the final architecture. The immediate priority is
to make the simulator and circuit model sufficiently complete to define a
useful QLOS intermediate representation and stable compiler/runtime interfaces
from working experience.

## Engineering Principles

### Correctness before optimization

Every operation should have tests for expected state evolution, normalization,
invalid input, and measurement behavior. Performance work should be driven by
repeatable benchmarks and profiling rather than assumptions.

### Stable semantics before broad APIs

QLOS should establish precise behavior for qubit indexing, gate parameters,
measurement results, circuit ownership, mutation, and errors before adding many
convenience interfaces.

### Circuits remain independent from execution backends

A circuit describes requested operations. A backend decides how those
operations are validated, lowered, and executed. Simulator-specific state must
not leak into the general circuit representation.

### The intermediate representation is the central contract

The long-term QLOS IR should connect frontends, compiler passes, exporters, and
execution backends. It must preserve program meaning while allowing operations
to be inspected, transformed, validated, serialized, and lowered without
depending on the syntax that originally produced them.

### Compiler and runtime responsibilities remain distinct

The compiler side answers how a program should be represented, analyzed,
transformed, and lowered for a target. The runtime side answers where and how
the lowered program is executed, how repeated shots and jobs are managed, and
how results and failures are reported. They share contracts without becoming
one undifferentiated subsystem.

### Common Lisp remains the primary environment

The project should use Lisp's interactive workflow, macros, conditions, generic
functions, and compilation model where they provide concrete value. External
formats and foreign kernels may be added without replacing the Lisp API.

### Capabilities are explicit

Backends will differ in gate sets, connectivity, measurement, reset,
conditional execution, timing, and limits. QLOS should expose these differences
through capability data instead of assuming every target behaves identically.

### Incremental architecture

New layers should be introduced only when the layer below has enough real use
cases to define them. The project should avoid designing a scheduler,
distributed control plane, or hardware abstraction around hypothetical needs.

## Target Architecture

```text
Lisp DSL       Imported formats       Future language frontends
   |                  |                          |
   +------------------+--------------------------+
                      |
                      v
             QLOS Intermediate Representation
                      |
          +-----------+------------+
          |                        |
          v                        v
 Validation, analysis,      Inspection, serialization,
 optimization, lowering        and resource estimation
          |
          v
 Target capability and backend lowering
          |
    +-----+-------------------------+
    |                               |
    v                               v
Simulator execution        Export/provider/hardware adapters
    |                               |
    +---------------+---------------+
                    |
                    v
         QLOS Runtime and Result Model
```

This structure permits multiple frontends and targets to share the same
compiler infrastructure. Runtime services such as repeated shots, job tracking,
result aggregation, and scheduling sit around backend execution rather than
inside the intermediate representation.

## Development Roadmap

### Stage 1: Complete the educational simulator core

The next simulator work should make small algorithms and meaningful
experiments possible:

- Add parameterized rotation gates.
- Support arbitrary computational-basis initialization.
- Add repeated-shot execution and count aggregation.
- Validate circuit operands and reject invalid operations early.
- Add deterministic random-state support to high-level execution APIs.
- Expand tests for phase, interference, collapse, and invalid input.
- Establish per-kernel benchmarks and allocation measurements.

Completion criterion: users can express, test, and repeatedly execute small
circuits without manually managing simulator internals.

### Stage 2: Establish the QLOS intermediate representation

The current instruction lists are intentionally small. Before supporting
multiple frontends, compiler passes, or backends, QLOS needs an intermediate
representation with explicit contracts:

- Define operation and parameter types.
- Separate quantum operations from classical results.
- Support circuit composition and reusable subcircuits.
- Represent measurement destinations and classical conditions.
- Add circuit metadata without coupling it to a backend.
- Provide readable printing and structured inspection.
- Decide and document mutability and ownership rules.
- Define verification rules and canonical forms.
- Provide a stable pass interface for analysis and transformation.

Completion criterion: different producers can create QLOS IR, passes can
consume and transform it, and backends can lower it without relying on
simulator-specific or frontend-specific details.

### Stage 3: Build reusable compiler infrastructure

Compiler work begins after the QLOS IR is stable enough to serve as a shared
contract:

- Gate decomposition into a requested basis.
- Adjacent inverse cancellation and simple gate simplification.
- Qubit usage and resource analysis.
- Connectivity-aware qubit mapping.
- Backend validation and unsupported-operation diagnostics.
- Pass composition with before-and-after inspection.
- Explicit analysis preservation and invalidation rules.
- Configurable compilation pipelines for different target requirements.

Optimization passes must preserve observable circuit behavior within documented
numeric tolerances. Like an LLVM pass pipeline, individual passes should remain
composable, independently testable, and useful to more than one frontend or
backend.

### Stage 4: Define the backend protocol

The simulator becomes one implementation of a general execution contract:

- Backend identity and capability discovery.
- Supported operations and parameter constraints.
- Qubit, memory, shot, and result limits.
- Synchronous execution as the first protocol.
- Standard result and error objects.
- Optional compilation or lowering hooks.

Initial non-simulator targets should favor interoperable exports such as
OpenQASM 3 before adding vendor-specific network integrations.

### Stage 5: Build the execution runtime

The QLOS runtime consumes validated or lowered programs and manages their
execution independently of how they were authored. Once multiple execution
targets exist, it can provide:

- Shot planning and result aggregation.
- Job identifiers and lifecycle state.
- Cancellation, timeout, and retry policies.
- Backend selection based on explicit requirements.
- Execution records and reproducibility metadata.
- Local and remote execution through the same user-facing entry points.
- A normalized result model across simulator and external backends.
- Clear boundaries between compile-time failures and execution-time failures.

Scheduling should begin as a small local abstraction. A distributed scheduler
is justified only when real multi-backend workloads require one.

### Stage 6: Advanced simulation and hardware support

Later work may include:

- Parallel and SIMD state-vector kernels.
- Gate fusion and compiled execution plans.
- Alternative simulation methods such as stabilizer or tensor-network
  backends.
- Noise channels and density-matrix simulation.
- Hardware provider adapters.
- Calibration-aware compilation and error mitigation.
- Distributed simulation for workloads that justify its complexity.

These are separate backend capabilities, not requirements imposed on every
QLOS implementation.

## Near-Term Performance Direction

The state-vector representation grows exponentially, so performance remains a
core concern. Near-term work should:

- Preserve specialized contiguous amplitude arrays.
- Benchmark gates and measurement independently across qubit counts.
- Record elapsed time, allocation, and garbage-collection behavior.
- Use compiler declarations only where profiling demonstrates a benefit.
- Avoid temporary full-state allocations in execution kernels.
- Maintain correctness tests around every optimized implementation.

GPU execution, foreign kernels, threading, and distributed state vectors should
follow profiling and stable kernel contracts rather than precede them.

## Interoperability Direction

QLOS should distinguish four forms of interoperability:

- **Frontend integration:** produce QLOS IR from another language or circuit
  representation.
- **Import/export:** translate circuits to or from formats such as OpenQASM.
- **Compilation target:** lower circuits according to a backend's gate and
  connectivity constraints.
- **Execution adapter:** submit work, monitor it, and normalize returned
  results.

Supporting a file format does not imply support for a provider, and supporting
a provider does not imply all of its hardware capabilities are available.

## Explicit Non-Goals For The Early Project

The early project is not trying to provide:

- A general-purpose operating system.
- A replacement for LLVM or a general-purpose classical compiler.
- Immediate compatibility with LLVM IR, MLIR, or QIR merely because the
  architecture is LLVM-inspired.
- A production cloud scheduler.
- Transparent support for every quantum hardware technology.
- Fault-tolerant compilation before basic circuit compilation is stable.
- A single representation that hides all backend differences.
- Performance claims without reproducible measurements.

The "Operating System" name describes the long-term coordinating role of the
compiler and runtime together. Near-term development remains focused on a
reliable simulator, a durable intermediate representation, reusable passes, and
backend-ready execution interfaces.

## Repository Evolution

The current small `src/` layout should remain until ownership boundaries become
clear. As components grow, likely ASDF systems include:

```text
qlos/core       Circuit and result data structures
qlos/ir         Intermediate representation and verification
qlos/simulator  State-vector backend
qlos/compiler   Validation and transformation passes
qlos/formats    External format import and export
qlos/runtime    Jobs, shots, and backend execution
qlos/tests      Cross-component correctness tests
```

Splitting systems should follow dependency boundaries and build-time needs, not
serve as a milestone by itself.

## Measures Of Progress

Project maturity should be evaluated through:

- Correctness coverage and documented semantics.
- Algorithms that can be expressed end to end.
- Stable IR, pass, runtime, and backend contracts.
- Multiple producers or frontends sharing the same IR.
- Multiple targets sharing compiler analyses and transformations.
- Reproducible benchmark history.
- Clear diagnostics for unsupported or invalid programs.
- Interoperability demonstrated by round trips or external execution.
- Runtime features justified by actual backend integrations.

The roadmap should be revised as implementation experience exposes better
boundaries or invalid assumptions.
