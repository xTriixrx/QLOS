(in-package #:qlos)

(defconstant +amplitude-bytes+ 16
  "Payload bytes used by one complex double-float amplitude.")

(defun estimated-state-vector-bytes (qubits)
  "Estimate payload bytes for a QUBITS-wide state vector.

The estimate multiplies 2^QUBITS amplitudes by the storage occupied by one
complex double-float.  Lisp object, array header, and runtime overhead are not
included."
  (check-type qubits (integer 1 *))
  (* +amplitude-bytes+ (ash 1 qubits)))

(defun make-benchmark-circuit (&key (qubits 20) (layers 4) measure)
  "Build a dense circuit intended to exercise the state-vector backend.

Each layer applies Hadamard gates to every qubit, a nearest-neighbor CNOT
ladder, and X gates to alternating qubits. When MEASURE is true, all qubits
are measured at the end.  The returned circuit is intended for repeatable
workload generation rather than as a correctness example."
  (check-type qubits (integer 2 *))
  (check-type layers (integer 1 *))
  (let ((circuit (make-circuit qubits)))
    ;; Begin with a full-register H pass so the subsequent operations exercise
    ;; more than the single nonzero amplitude in the initial state.
    (dotimes (qubit qubits)
      (circuit-h circuit qubit))
    (dotimes (layer layers)
      (dotimes (qubit qubits)
        (circuit-h circuit qubit))
      (dotimes (qubit (1- qubits))
        ;; Alternate CNOT direction by layer so the benchmark does not repeat
        ;; an identical nearest-neighbor access pattern.
        (if (evenp layer)
            (circuit-cnot circuit qubit (1+ qubit))
            (circuit-cnot circuit (1+ qubit) qubit)))
      ;; Offset alternating X gates on successive layers.
      (loop for qubit from (mod layer 2) below qubits by 2
            do (circuit-x circuit qubit)))
    (when measure
      (dotimes (qubit qubits)
        (circuit-measure circuit qubit)))
    circuit))

(defun %megabytes (bytes)
  "Convert BYTES to mebibytes for human-readable benchmark output."
  (/ bytes 1024.0d0 1024.0d0))

(defun benchmark-simulator (&key
                             (qubits 20)
                             (layers 4)
                             measure
                             (maximum-state-vector-bytes
                               (* 1024 1024 1024)))
  "Build and run a dense simulator benchmark.

The default memory guard permits at most a 1 GiB state-vector payload. Return
two values: a result property list and the final quantum state.  The property
list includes workload size, elapsed time, throughput, and measurements."
  (let ((state-bytes (estimated-state-vector-bytes qubits)))
    ;; Fail before constructing the circuit or allocating the state vector when
    ;; the requested payload exceeds the caller's explicit memory allowance.
    (when (> state-bytes maximum-state-vector-bytes)
      (error "A ~D-qubit state vector needs approximately ~,2F GiB.~
 Increase MAXIMUM-STATE-VECTOR-BYTES explicitly if that allocation is intended."
             qubits (/ state-bytes 1024.0d0 1024.0d0 1024.0d0)))
    (let* ((circuit (make-benchmark-circuit
                     :qubits qubits :layers layers :measure measure))
           (operation-count (length (circuit-operations circuit)))
           (start (get-internal-real-time)))
      (multiple-value-bind (state measurements)
          (run-circuit circuit)
        ;; GET-INTERNAL-REAL-TIME reports implementation-specific ticks.
        ;; Convert after execution so all reported rates use seconds.
        (let* ((ticks (- (get-internal-real-time) start))
               (seconds (/ ticks
                           (coerce internal-time-units-per-second
                                   'double-float)))
               (operations-per-second
                 (if (plusp seconds) (/ operation-count seconds) 0.0d0))
               (result
                 (list :qubits qubits
                       :amplitudes (ash 1 qubits)
                       :state-vector-bytes state-bytes
                       :operations operation-count
                       :seconds seconds
                       :operations-per-second operations-per-second
                       :measurements measurements)))
          (format t "~&QLOS state-vector benchmark~%")
          (format t "  Qubits:               ~:D~%" qubits)
          (format t "  Amplitudes:           ~:D~%" (ash 1 qubits))
          (format t "  State-vector payload: ~,2F MiB~%"
                  (%megabytes state-bytes))
          (format t "  Operations:           ~:D~%" operation-count)
          (format t "  Elapsed:              ~,3F seconds~%" seconds)
          (format t "  Operations/second:    ~,2F~%" operations-per-second)
          (values result state))))))
