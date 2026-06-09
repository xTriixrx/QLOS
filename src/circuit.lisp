(in-package #:qlos)

(defstruct (quantum-circuit
             (:constructor make-circuit (qubit-count)))
  "An ordered program for a fixed-size quantum register.

Operations are accumulated in reverse order for constant-time insertion.
Use CIRCUIT-OPERATIONS to obtain a caller-owned list in execution order."
  (qubit-count 1 :type (integer 1 *) :read-only t)
  (operations '() :type list))

(defun %append-operation (circuit operation)
  "Add OPERATION to CIRCUIT's internal instruction list and return CIRCUIT."
  ;; PUSH keeps circuit construction constant-time.  The list is reversed only
  ;; when callers request operations for inspection or execution.
  (push operation (quantum-circuit-operations circuit))
  circuit)

(defun circuit-x (circuit qubit)
  "Append an X operation for QUBIT to CIRCUIT and return CIRCUIT."
  (%append-operation circuit (list :x qubit)))

(defun circuit-h (circuit qubit)
  "Append a Hadamard operation for QUBIT to CIRCUIT and return CIRCUIT."
  (%append-operation circuit (list :h qubit)))

(defun circuit-z (circuit qubit)
  "Append a Z operation for QUBIT to CIRCUIT and return CIRCUIT."
  (%append-operation circuit (list :z qubit)))

(defun circuit-s (circuit qubit)
  "Append an S operation for QUBIT to CIRCUIT and return CIRCUIT."
  (%append-operation circuit (list :s qubit)))

(defun circuit-t (circuit qubit)
  "Append a T operation for QUBIT to CIRCUIT and return CIRCUIT."
  (%append-operation circuit (list :t qubit)))

(defun circuit-rx (circuit qubit angle)
  "Append an RX rotation of QUBIT by ANGLE radians and return CIRCUIT."
  (%append-operation circuit (list :rx qubit angle)))

(defun circuit-ry (circuit qubit angle)
  "Append an RY rotation of QUBIT by ANGLE radians and return CIRCUIT."
  (%append-operation circuit (list :ry qubit angle)))

(defun circuit-rz (circuit qubit angle)
  "Append an RZ rotation of QUBIT by ANGLE radians and return CIRCUIT."
  (%append-operation circuit (list :rz qubit angle)))

(defun circuit-cnot (circuit control target)
  "Append a CNOT operation from CONTROL to TARGET and return CIRCUIT."
  (%append-operation circuit (list :cnot control target)))

(defun circuit-measure (circuit qubit)
  "Append a measurement of QUBIT to CIRCUIT and return CIRCUIT."
  (%append-operation circuit (list :measure qubit)))

(defun circuit-qubit-count (circuit)
  "Return the number of qubits required by CIRCUIT."
  (quantum-circuit-qubit-count circuit))

(defun circuit-operations (circuit)
  "Return a caller-owned copy of CIRCUIT's operations in execution order."
  ;; COPY-TREE protects both the operation list and each instruction from
  ;; mutation while NREVERSE restores the insertion order.
  (nreverse (copy-tree (quantum-circuit-operations circuit))))

(defun run-circuit (circuit &key
                              (state (make-zero-state
                                      (quantum-circuit-qubit-count circuit)))
                              (random-state *random-state*))
  "Execute CIRCUIT and return two values: the final state and measurements.

STATE defaults to a new all-zero state and is otherwise mutated in place.
RANDOM-STATE is passed to every measurement.  Measurements are returned in
execution order as (QUBIT . BIT) pairs."
  (unless (= (quantum-state-qubit-count state)
             (quantum-circuit-qubit-count circuit))
    (error "Circuit has ~D qubits but initial state has ~D."
           (quantum-circuit-qubit-count circuit)
           (quantum-state-qubit-count state)))
  (let ((measurements '()))
    (dolist (operation (circuit-operations circuit))
      ;; Operations form a deliberately small intermediate representation:
      ;; the keyword selects a kernel and the remaining elements are operands.
      (case (first operation)
        (:x (x state (second operation)))
        (:h (h state (second operation)))
        (:z (z state (second operation)))
        (:s (s state (second operation)))
        (:t (t-gate state (second operation)))
        (:rx (rx state (second operation) (third operation)))
        (:ry (ry state (second operation) (third operation)))
        (:rz (rz state (second operation) (third operation)))
        (:cnot (cnot state (second operation) (third operation)))
        (:measure
         (push (cons (second operation)
                     (measure state (second operation) random-state))
               measurements))
        (otherwise
         (error "Unknown circuit operation: ~S" operation))))
    ;; Measurements were pushed for constant-time collection, so restore their
    ;; execution order before returning them to the caller.
    (values state (nreverse measurements))))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun %circuit-operation-name (form)
    "Return FORM's operation symbol as a package-independent keyword."
    ;; Looking only at SYMBOL-NAME permits forms such as CL-USER::H and QLOS:H
    ;; to be treated as the same DSL operation.
    (intern (string-upcase (symbol-name (first form))) :keyword))

  (defun %circuit-form-qubits (form)
    "Return the literal qubit operands referenced by a QCIRCUIT FORM."
    (case (%circuit-operation-name form)
      ((:x :h :z :s :t :rx :ry :rz :measure) (list (second form)))
      (:cnot (list (second form) (third form)))
      (otherwise (error "Unknown QCIRCUIT operation: ~S" form)))))

(defmacro qcircuit (&body operations)
  "Build and return a circuit from literal operation forms.

Supported forms are (X QUBIT), (H QUBIT), (Z QUBIT), (S QUBIT), (T QUBIT),
(RX QUBIT ANGLE), (RY QUBIT ANGLE), (RZ QUBIT ANGLE),
(CNOT CONTROL TARGET), and (MEASURE QUBIT).  Rotation angles are in radians.
The circuit width is inferred from the greatest referenced zero-based qubit
index."
  (when (null operations)
    (error "QCIRCUIT requires at least one operation."))
  (let* ((qubits (mapcan #'%circuit-form-qubits operations))
         ;; A greatest index of N requires a register containing N+1 qubits.
         (count (1+ (apply #'max qubits)))
         (circuit (gensym "CIRCUIT")))
    ;; Emit calls to the procedural circuit builder.  The macro keeps the
    ;; user-facing syntax compact while retaining one circuit representation.
    `(let ((,circuit (make-circuit ,count)))
       ,@(mapcar
          (lambda (operation)
            (ecase (%circuit-operation-name operation)
              (:x `(circuit-x ,circuit ,(second operation)))
              (:h `(circuit-h ,circuit ,(second operation)))
              (:z `(circuit-z ,circuit ,(second operation)))
              (:s `(circuit-s ,circuit ,(second operation)))
              (:t `(circuit-t ,circuit ,(second operation)))
              (:rx `(circuit-rx ,circuit
                                ,(second operation)
                                ,(third operation)))
              (:ry `(circuit-ry ,circuit
                                ,(second operation)
                                ,(third operation)))
              (:rz `(circuit-rz ,circuit
                                ,(second operation)
                                ,(third operation)))
              (:cnot `(circuit-cnot ,circuit
                                    ,(second operation)
                                    ,(third operation)))
              (:measure `(circuit-measure ,circuit ,(second operation)))))
          operations)
       ,circuit)))
