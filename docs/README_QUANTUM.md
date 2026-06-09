# Quantum Computing With QLOS

This guide introduces the quantum-computing ideas needed to understand and
experiment with the current QLOS simulator. It assumes basic programming
experience but no prior quantum mechanics.

For installation and API usage, begin with the
[project README](../README.md). For project direction, see
[QLOS Project Direction](README_QLOS.md).

## A Practical Learning Path

Use the current simulator in this order:

1. Create and inspect a one-qubit state.
2. Apply `X` and observe deterministic state changes.
3. Apply `H` and inspect both amplitudes and probabilities.
4. Apply `H` twice to see interference.
5. Build a two-qubit circuit with `H` and `CNOT`.
6. Measure copied states repeatedly to observe correlated outcomes.

The examples below use the exported `qlos:` package prefix. Load QLOS as
described in the project README before evaluating them.

## Classical Bits, Qubits, And Registers

A classical bit has one definite value, zero or one. A qubit state is described
by two complex amplitudes:

```text
alpha|0> + beta|1>
```

`|0>` and `|1>` are basis states. `alpha` and `beta` are amplitudes, not
probabilities. Measurement probabilities are their squared magnitudes:

```text
P(0) = |alpha|^2
P(1) = |beta|^2
```

A valid state is normalized:

```text
|alpha|^2 + |beta|^2 = 1
```

QLOS represents a register as one state vector for the entire system. An
`n`-qubit register needs `2^n` amplitudes:

```text
1 qubit  -> 2 amplitudes
2 qubits -> 4 amplitudes
3 qubits -> 8 amplitudes
20 qubits -> 1,048,576 amplitudes
```

This exponential growth is why state-vector simulators are useful for learning
and small workloads but cannot efficiently represent arbitrarily large
registers.

## Creating And Inspecting A State

`make-zero-state` creates a register in the all-zero basis state:

```lisp
(defparameter *state* (qlos:make-zero-state 2))

(qlos:amplitudes *state*)
;; => #(#C(1.0d0 0.0d0)
;;      #C(0.0d0 0.0d0)
;;      #C(0.0d0 0.0d0)
;;      #C(0.0d0 0.0d0))

(qlos:probabilities *state*)
;; => #(1.0d0 0.0d0 0.0d0 0.0d0)
```

The first amplitude is one, so the register is certainly in its all-zero
state. `normalized-p` checks that the probabilities sum to approximately one:

```lisp
(qlos:normalized-p *state*)
;; => T
```

## Qubit Numbering And Vector Indices

QLOS uses zero-based, little-endian qubit indexing. Qubit zero is the
least-significant bit of an amplitude-vector index.

For two qubits:

| Vector index | Binary index | Basis state |
|---:|:---:|:---:|
| 0 | `00` | `|00>` |
| 1 | `01` | `|01>` |
| 2 | `10` | `|10>` |
| 3 | `11` | `|11>` |

Applying `X` to qubit zero changes `|00>` to `|01>`:

```lisp
(let ((state (qlos:make-zero-state 2)))
  (qlos:x state 0)
  (qlos:probabilities state))
;; => #(0.0d0 1.0d0 0.0d0 0.0d0)
```

Applying `X` to qubit one changes `|00>` to `|10>`:

```lisp
(let ((state (qlos:make-zero-state 2)))
  (qlos:x state 1)
  (qlos:probabilities state))
;; => #(0.0d0 0.0d0 1.0d0 0.0d0)
```

Keeping this convention in mind is essential when comparing array indices with
written bit strings.

## Gates Are Deterministic Transformations

Quantum gates transform amplitudes. They do not randomly choose an output.
Random sampling occurs during measurement.

For one qubit, a gate can be represented by a `2 x 2` matrix. QLOS applies that
matrix to every relevant pair of amplitudes in the full register.

### Pauli-X

The `X` gate exchanges the zero and one amplitudes:

```text
X = [0 1]
    [1 0]
```

```lisp
(let ((state (qlos:make-zero-state 1)))
  (qlos:x state 0)
  (qlos:probabilities state))
;; => #(0.0d0 1.0d0)
```

Applying `X` twice restores the initial state.

### Hadamard

The Hadamard gate is:

```text
H = 1/sqrt(2) [ 1  1]
              [ 1 -1]
```

Starting from `|0>`, it creates equal-magnitude amplitudes:

```lisp
(let ((state (qlos:make-zero-state 1)))
  (qlos:h state 0)
  (values (qlos:amplitudes state)
          (qlos:probabilities state)))
;; amplitudes are approximately #(0.7071 0.7071)
;; probabilities are approximately #(0.5 0.5)
```

The state has not selected zero or one. It remains one quantum state with two
nonzero amplitudes until measurement.

## Phase And Interference

Amplitudes can be positive, negative, or complex. Probabilities alone do not
retain this phase information.

Applying `H` twice demonstrates why phase matters:

```lisp
(let ((state (qlos:make-zero-state 1)))
  (qlos:h state 0)
  (qlos:h state 0)
  (qlos:probabilities state))
;; => approximately #(1.0d0 0.0d0)
```

During the second gate, amplitude contributions add for `|0>` and cancel for
`|1>`. This is interference. It is not equivalent to flipping a fair coin
twice.

The current QLOS gate set has limited phase manipulation. Future `Z`, `S`, `T`,
and rotation gates will make phase experiments more direct.

## Multiple Qubits And Entanglement

For multiple qubits, QLOS stores amplitudes for the joint register rather than
separate state vectors for each qubit. This permits states that cannot be
factored into independent single-qubit states.

Create a Bell state:

```lisp
(let ((state (qlos:make-zero-state 2)))
  (qlos:h state 0)
  (qlos:cnot state 0 1)
  (qlos:probabilities state))
;; => approximately #(0.5d0 0.0d0 0.0d0 0.5d0)
```

The transformation is:

```text
|00>
  -- H on qubit 0 --> (|00> + |01>)/sqrt(2)
  -- CNOT 0 to 1 -->  (|00> + |11>)/sqrt(2)
```

Only `|00>` and `|11>` have nonzero probability. Individual measurements are
unpredictable, but measurements of the two qubits agree.

## Measurement And Collapse

`measure`:

1. Calculates the probability of the requested qubit being one.
2. Samples zero or one using the supplied random state.
3. Sets amplitudes incompatible with that result to zero.
4. Renormalizes the remaining amplitudes.
5. Returns the sampled bit.

Measurement mutates the state:

```lisp
(let ((state (qlos:make-zero-state 1)))
  (qlos:h state 0)
  (let ((result (qlos:measure state 0)))
    (values result
            (qlos:probabilities state))))
;; => 0 and #(1.0d0 0.0d0), or
;; => 1 and #(0.0d0 1.0d0)
```

Measuring the same qubit again immediately returns the same result because the
first measurement collapsed the state.

## Repeating Experiments Correctly

A state is mutated by gates and measurement. Reusing a measured state does not
start another independent trial.

Prepare a state once and copy it for each experiment:

```lisp
(let ((prepared (qlos:make-zero-state 1)))
  (qlos:h prepared 0)
  (loop repeat 10
        collect (qlos:measure
                 (qlos:copy-quantum-state prepared)
                 0)))
```

The current project does not yet provide a high-level repeated-shot count API,
so callers must currently perform this loop themselves.

For a Bell-state correlation experiment:

```lisp
(let ((prepared (qlos:make-zero-state 2)))
  (qlos:h prepared 0)
  (qlos:cnot prepared 0 1)
  (loop repeat 10
        collect
        (let* ((state (qlos:copy-quantum-state prepared))
               (first (qlos:measure state 0))
               (second (qlos:measure state 1)))
          (list first second))))
;; every pair is either (0 0) or (1 1)
```

## Circuits As Experiments

The same Bell experiment can be represented as a circuit:

```lisp
(defparameter *bell-circuit*
  (qlos:qcircuit
    (h 0)
    (cnot 0 1)
    (measure 0)
    (measure 1)))

(multiple-value-bind (state measurements)
    (qlos:run-circuit *bell-circuit*)
  (values (qlos:probabilities state)
          measurements))
```

Each call to `run-circuit` without a supplied state creates a new all-zero
state, so repeated calls are independent executions.

## Suggested Exercises

### Exercise 1: Reversible X

Create a one-qubit state, apply `X` twice, and verify that its probabilities
return to `#(1.0d0 0.0d0)`.

### Exercise 2: Hadamard interference

Inspect amplitudes after one, two, three, and four applications of `H`. Compare
the amplitudes as well as the probabilities.

### Exercise 3: Qubit ordering

Create a three-qubit state and apply `X` separately to qubits zero, one, and
two. Predict the nonzero vector index before evaluating each case.

### Exercise 4: Bell correlations

Prepare a Bell state, copy it 100 times, and count the observed `(0 0)` and
`(1 1)` pairs. Confirm that `(0 1)` and `(1 0)` do not occur.

### Exercise 5: Collapse order

Prepare a Bell state and measure qubit one before qubit zero. Confirm that the
results remain correlated.

## Common Beginner Mistakes

- Treating amplitudes as probabilities instead of squaring their magnitudes.
- Expecting a gate application to produce a random classical result.
- Ignoring negative or complex amplitudes because probabilities look equal.
- Forgetting that QLOS qubit zero is the least-significant index bit.
- Reusing a state after measurement when an independent trial was intended.
- Assuming two entangled qubits have separate independent state vectors.
- Comparing floating-point values with exact equality.
- Interpreting simulator behavior as a model of hardware noise or timing.

## What QLOS Currently Models

The current simulator models:

- Ideal pure states.
- Unitary `X`, `H`, and `CNOT` operations.
- Computational-basis measurement.
- State collapse and renormalization.
- Exact circuit ordering with floating-point arithmetic.

It does not currently model:

- Noise, decoherence, or calibration error.
- Mixed states or density matrices.
- Physical gate duration or device connectivity.
- Reset or classically conditioned gates.
- Phase gates and arbitrary rotations.
- Hardware execution.

These limitations matter when moving from simulator exercises to real quantum
devices.

## Reading The Implementation

The implementation maps closely to the concepts in this guide:

- `src/state.lisp` defines state storage, probabilities, normalization, and
  measurement.
- `src/gates.lisp` applies matrix transformations and implements CNOT.
- `src/circuit.lisp` records and executes circuit operations.
- `tests/simulator.lisp` contains executable examples of expected behavior.

A useful reading order is `state.lisp`, `gates.lisp`, `circuit.lisp`, then the
tests.

## Next Topics

After understanding the current simulator, useful next subjects are:

- Tensor products and multi-qubit gate matrices.
- Global phase versus relative phase.
- Bloch-sphere representations of one-qubit states.
- Parameterized rotations.
- Repeated shots and statistical uncertainty.
- Density matrices and noise channels.
- Circuit decomposition and hardware-native gate sets.

The [QLOS project roadmap](README_QLOS.md) explains how several of these topics
fit into future implementation stages.
