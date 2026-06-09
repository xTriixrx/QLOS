(defpackage #:qlos
  (:use #:cl)
  (:export
   ;; State vectors
   #:quantum-state
   #:make-zero-state
   #:copy-quantum-state
   #:qubit-count
   #:amplitudes
   #:probabilities
   #:normalized-p
   #:measure
   ;; Gates
   #:x
   #:h
   #:z
   #:s
   #:t-gate
   #:cnot
   ;; Circuits
   #:quantum-circuit
   #:make-circuit
   #:circuit-qubit-count
   #:circuit-operations
   #:circuit-x
   #:circuit-h
   #:circuit-z
   #:circuit-s
   #:circuit-t
   #:circuit-cnot
   #:circuit-measure
   #:run-circuit
   #:qcircuit
   ;; Benchmarks
   #:make-benchmark-circuit
   #:benchmark-simulator
   #:estimated-state-vector-bytes))

(in-package #:qlos)
