(in-package #:qlos/tests)

(defun approximately= (left right &optional (tolerance 1.0d-12))
  "Return true when LEFT and RIGHT differ by less than TOLERANCE."
  (< (abs (- left right)) tolerance))

(defun approximately-vector= (left right &optional (tolerance 1.0d-12))
  "Return true when corresponding entries in LEFT and RIGHT are approximately equal."
  (and (= (length left) (length right))
       (loop for index below (length left)
             always (approximately= (aref left index)
                                    (aref right index)
                                    tolerance))))

(defun apply-one-qubit-gates (initial-bit gates)
  "Apply GATES to an initial one-qubit basis state and return its amplitudes."
  (let ((state (make-zero-state 1)))
    (when (= initial-bit 1)
      (x state 0))
    (dolist (gate gates)
      (funcall gate state 0))
    (amplitudes state)))

(defun one-qubit-gate-sequences= (left right)
  "Return true when LEFT and RIGHT act equally on both basis states."
  (loop for initial-bit from 0 to 1
        always (approximately-vector=
                (apply-one-qubit-gates initial-bit left)
                (apply-one-qubit-gates initial-bit right))))

(defun approximately-vector-up-to-global-phase=
    (left right &optional (tolerance 1.0d-12))
  "Return true when LEFT and RIGHT differ only by one unit global phase."
  (when (= (length left) (length right))
    (let ((pivot (position-if
                  (lambda (value) (> (abs value) tolerance))
                  right)))
      (if (null pivot)
          (approximately-vector= left right tolerance)
          (let ((phase (/ (aref left pivot) (aref right pivot))))
            (and (approximately= (abs phase) 1.0d0 tolerance)
                 (loop for index below (length left)
                       always
                       (approximately= (aref left index)
                                       (* phase (aref right index))
                                       tolerance))))))))

(defun one-qubit-gate-sequences-equal-up-to-global-phase-p (left right)
  "Compare two one-qubit operators while ignoring one shared global phase."
  (approximately-vector-up-to-global-phase=
   (concatenate 'vector
                (apply-one-qubit-gates 0 left)
                (apply-one-qubit-gates 1 left))
   (concatenate 'vector
                (apply-one-qubit-gates 0 right)
                (apply-one-qubit-gates 1 right))))

(defun make-basis-state (qubit-count basis-index)
  "Create QUBIT-COUNT qubits initialized to BASIS-INDEX."
  (let ((state (make-zero-state qubit-count)))
    (dotimes (qubit qubit-count state)
      (when (logbitp qubit basis-index)
        (x state qubit)))))

(deftest zero-state
  (let ((state (make-zero-state 2)))
    (ok (equalp (amplitudes state)
                #(#C(1.0d0 0.0d0)
                  #C(0.0d0 0.0d0)
                  #C(0.0d0 0.0d0)
                  #C(0.0d0 0.0d0))))
    (ok (normalized-p state))))

(deftest x-gate
  (testing "X |0> = |1>"
    (ok (approximately-vector=
         (apply-one-qubit-gates 0 (list #'x))
         #(#C(0.0d0 0.0d0) #C(1.0d0 0.0d0)))))
  (testing "X maps |1> to |0>"
    (ok (approximately-vector=
         (apply-one-qubit-gates 1 (list #'x))
         #(#C(1.0d0 0.0d0) #C(0.0d0 0.0d0))))))

(deftest h-gate
  (let ((inverse-sqrt-two (/ 1.0d0 (sqrt 2.0d0))))
    (testing "H |0> = (|0> + |1>)/sqrt(2)"
      (ok (approximately-vector=
           (apply-one-qubit-gates 0 (list #'h))
           (vector (complex inverse-sqrt-two 0.0d0)
                   (complex inverse-sqrt-two 0.0d0)))))
    (testing "H maps |1> to amplitudes with opposite signs"
      (ok (approximately-vector=
           (apply-one-qubit-gates 1 (list #'h))
           (vector (complex inverse-sqrt-two 0.0d0)
                   (complex (- inverse-sqrt-two) 0.0d0)))))))

(deftest z-gate
  (testing "Z leaves |0> unchanged"
    (ok (approximately-vector=
         (apply-one-qubit-gates 0 (list #'z))
         #(#C(1.0d0 0.0d0) #C(0.0d0 0.0d0)))))
  (testing "Z |1> = -|1>"
    (ok (approximately-vector=
         (apply-one-qubit-gates 1 (list #'z))
         #(#C(0.0d0 0.0d0) #C(-1.0d0 0.0d0))))))

(deftest s-gate
  (testing "S leaves |0> unchanged"
    (ok (approximately-vector=
         (apply-one-qubit-gates 0 (list #'s))
         #(#C(1.0d0 0.0d0) #C(0.0d0 0.0d0)))))
  (testing "S |1> = i|1>"
    (ok (approximately-vector=
         (apply-one-qubit-gates 1 (list #'s))
         #(#C(0.0d0 0.0d0) #C(0.0d0 1.0d0))))))

(deftest t-gate-test
  (let ((inverse-sqrt-two (/ 1.0d0 (sqrt 2.0d0))))
    (testing "T leaves |0> unchanged"
      (ok (approximately-vector=
           (apply-one-qubit-gates 0 (list #'t-gate))
           #(#C(1.0d0 0.0d0) #C(0.0d0 0.0d0)))))
    (testing "T |1> = exp(i*pi/4)|1>"
      (ok (approximately-vector=
           (apply-one-qubit-gates 1 (list #'t-gate))
           (vector #C(0.0d0 0.0d0)
                   (complex inverse-sqrt-two inverse-sqrt-two)))))))

(deftest rx-gate
  (testing "RX(pi) |0> = -i|1>"
    (ok (approximately-vector=
         (apply-one-qubit-gates
          0 (list (lambda (state qubit) (rx state qubit pi))))
         #(#C(0.0d0 0.0d0) #C(0.0d0 -1.0d0)))))
  (testing "RX preserves normalization for a nontrivial angle"
    (let ((state (make-zero-state 1)))
      (rx state 0 (/ pi 3))
      (ok (normalized-p state)))))

(deftest ry-gate
  (testing "RY(pi) |0> = |1>"
    (ok (approximately-vector=
         (apply-one-qubit-gates
          0 (list (lambda (state qubit) (ry state qubit pi))))
         #(#C(0.0d0 0.0d0) #C(1.0d0 0.0d0)))))
  (testing "RY(pi) |1> = -|0>"
    (ok (approximately-vector=
         (apply-one-qubit-gates
          1 (list (lambda (state qubit) (ry state qubit pi))))
         #(#C(-1.0d0 0.0d0) #C(0.0d0 0.0d0))))))

(deftest rz-gate
  (let ((inverse-sqrt-two (/ 1.0d0 (sqrt 2.0d0))))
    (testing "RZ(pi/2) applies opposite phases to |0> and |1>"
      (ok (approximately-vector=
           (apply-one-qubit-gates
            0 (list (lambda (state qubit) (rz state qubit (/ pi 2)))))
           (vector (complex inverse-sqrt-two (- inverse-sqrt-two))
                   #C(0.0d0 0.0d0))))
      (ok (approximately-vector=
           (apply-one-qubit-gates
            1 (list (lambda (state qubit) (rz state qubit (/ pi 2)))))
           (vector #C(0.0d0 0.0d0)
                   (complex inverse-sqrt-two inverse-sqrt-two)))))))

(deftest cnot-gate
  (testing "CNOT maps every computational basis state correctly"
    (dolist (mapping '((0 . 0) (1 . 3) (2 . 2) (3 . 1)))
      (let ((state (make-basis-state 2 (car mapping)))
            (expected (make-basis-state 2 (cdr mapping))))
        (cnot state 0 1)
        (ok (approximately-vector= (amplitudes state)
                                   (amplitudes expected))
            (format nil "CNOT maps basis index ~D to ~D"
                    (car mapping) (cdr mapping)))))))

(deftest t-squared-equals-s
  (ok (one-qubit-gate-sequences=
       (list #'t-gate #'t-gate)
       (list #'s))))

(deftest s-squared-equals-z
  (ok (one-qubit-gate-sequences=
       (list #'s #'s)
       (list #'z))))

(deftest t-fourth-equals-z
  (ok (one-qubit-gate-sequences=
       (list #'t-gate #'t-gate #'t-gate #'t-gate)
       (list #'z))))

(deftest t-eighth-equals-identity
  (ok (one-qubit-gate-sequences=
       (loop repeat 8 collect #'t-gate)
       '())))

(deftest s-fourth-equals-identity
  (ok (one-qubit-gate-sequences=
       (list #'s #'s #'s #'s)
       '())))

(deftest x-squared-equals-identity
  (ok (one-qubit-gate-sequences= (list #'x #'x) '())))

(deftest h-squared-equals-identity
  (ok (one-qubit-gate-sequences= (list #'h #'h) '())))

(deftest z-squared-equals-identity
  (ok (one-qubit-gate-sequences= (list #'z #'z) '())))

(deftest h-z-h-equals-x
  (ok (one-qubit-gate-sequences=
       (list #'h #'z #'h)
       (list #'x))))

(deftest h-x-h-equals-z
  (ok (one-qubit-gate-sequences=
       (list #'h #'x #'h)
       (list #'z))))

(deftest rx-pi-equals-x-up-to-global-phase
  (ok (one-qubit-gate-sequences-equal-up-to-global-phase-p
       (list (lambda (state qubit) (rx state qubit pi)))
       (list #'x))))

(deftest rz-pi-equals-z-up-to-global-phase
  (ok (one-qubit-gate-sequences-equal-up-to-global-phase-p
       (list (lambda (state qubit) (rz state qubit pi)))
       (list #'z))))

(deftest rz-half-pi-equals-s-up-to-global-phase
  (ok (one-qubit-gate-sequences-equal-up-to-global-phase-p
       (list (lambda (state qubit) (rz state qubit (/ pi 2))))
       (list #'s))))

(deftest rz-quarter-pi-equals-t-up-to-global-phase
  (ok (one-qubit-gate-sequences-equal-up-to-global-phase-p
       (list (lambda (state qubit) (rz state qubit (/ pi 4))))
       (list #'t-gate))))

(deftest rx-inverse-rotation-equals-identity
  (ok (one-qubit-gate-sequences=
       (list (lambda (state qubit) (rx state qubit (/ pi 3)))
             (lambda (state qubit) (rx state qubit (- (/ pi 3)))))
       '())))

(deftest ry-inverse-rotation-equals-identity
  (ok (one-qubit-gate-sequences=
       (list (lambda (state qubit) (ry state qubit (/ pi 3)))
             (lambda (state qubit) (ry state qubit (- (/ pi 3)))))
       '())))

(deftest rz-inverse-rotation-equals-identity
  (ok (one-qubit-gate-sequences=
       (list (lambda (state qubit) (rz state qubit (/ pi 3)))
             (lambda (state qubit) (rz state qubit (- (/ pi 3)))))
       '())))

(deftest cnot-squared-equals-identity
  (dotimes (basis-index 4)
    (let* ((state (make-basis-state 2 basis-index))
           (initial (amplitudes state)))
      (cnot state 0 1)
      (cnot state 0 1)
      (ok (approximately-vector= initial (amplitudes state))
          (format nil "CNOT^2 restores basis index ~D" basis-index)))))

(deftest bell-state
  (let ((state (make-zero-state 2))
        (inverse-sqrt-two (/ 1.0d0 (sqrt 2.0d0))))
    (h state 0)
    (cnot state 0 1)
    (testing "H on q0 followed by CNOT q0 q1 creates a Bell state"
      (ok (approximately-vector=
           (amplitudes state)
           (vector (complex inverse-sqrt-two 0.0d0)
                   #C(0.0d0 0.0d0)
                   #C(0.0d0 0.0d0)
                   (complex inverse-sqrt-two 0.0d0)))))
    (let ((probabilities (probabilities state)))
      (ok (approximately= 0.5d0 (aref probabilities 0)))
      (ok (approximately= 0.0d0 (aref probabilities 1)))
      (ok (approximately= 0.0d0 (aref probabilities 2)))
      (ok (approximately= 0.5d0 (aref probabilities 3))))
    (testing "measurement collapses both qubits to correlated values"
      (dotimes (shot 20)
        (let* ((measured-state (copy-quantum-state state))
               (first (measure measured-state 0))
               (second (measure measured-state 1)))
          (ok (= first second)
              (format nil "Bell measurements agree on shot ~D" shot)))))))

(deftest circuit-execution
  (let ((circuit (qcircuit
                   (h 0)
                   (cnot 0 1)
                   (measure 0)
                   (measure 1))))
    (multiple-value-bind (state measurements)
        (run-circuit circuit)
      (ok (normalized-p state))
      (ok (= (cdar measurements)
             (cdr (second measurements)))))))

(deftest circuit-operators-are-package-independent
  (let ((circuit (qcircuit
                   (cl-user::h 0)
                   (cl-user::z 0)
                   (cl-user::s 0)
                   (cl-user::t 0)
                   (cl-user::measure 0))))
    (multiple-value-bind (state measurements)
        (run-circuit circuit)
      (ok (normalized-p state))
      (ok (= 1 (length measurements))))))

(deftest phase-gate-circuit-execution
  (let ((circuit (qcircuit
                   (x 0)
                   (z 0)
                   (s 0)
                   (t 0))))
    (ok (equal (qlos:circuit-operations circuit)
               '((:x 0) (:z 0) (:s 0) (:t 0))))
    (multiple-value-bind (state measurements)
        (run-circuit circuit)
      (ok (null measurements))
      (let* ((inverse-sqrt-two (/ 1.0d0 (sqrt 2.0d0)))
             (expected (complex inverse-sqrt-two (- inverse-sqrt-two))))
        (ok (approximately= expected
                            (aref (amplitudes state) 1))))
      (ok (normalized-p state)))))

(deftest rotation-gate-circuit-execution
  (let ((circuit (qcircuit
                   (rx 0 0.25d0)
                   (ry 0 0.5d0)
                   (rz 0 0.75d0))))
    (ok (equal (qlos:circuit-operations circuit)
               '((:rx 0 0.25d0) (:ry 0 0.5d0) (:rz 0 0.75d0))))
    (multiple-value-bind (state measurements)
        (run-circuit circuit)
      (ok (null measurements))
      (ok (normalized-p state)))))

(deftest benchmark-circuit
  (let ((circuit (make-benchmark-circuit :qubits 4 :layers 2)))
    (ok (= 4 (qlos:circuit-qubit-count circuit)))
    (ok (= 22 (length (qlos:circuit-operations circuit))))
    (ok (= (* 16 (expt 2 20))
           (estimated-state-vector-bytes 20)))
    (multiple-value-bind (state measurements)
        (run-circuit circuit)
      (ok (null measurements))
      (ok (normalized-p state)))))
