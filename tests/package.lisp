(defpackage #:qlos/tests
  (:use #:cl #:rove)
  (:import-from #:qlos
                #:make-zero-state
                #:copy-quantum-state
                #:amplitudes
                #:probabilities
                #:normalized-p
                #:x
                #:h
                #:z
                #:s
                #:t-gate
                #:cnot
                #:measure
                #:qcircuit
                #:run-circuit
                #:make-benchmark-circuit
                #:estimated-state-vector-bytes))

(in-package #:qlos/tests)
