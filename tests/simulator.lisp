(in-package #:qlos/tests)

(defun approximately= (left right &optional (tolerance 1.0d-12))
  "Return true when LEFT and RIGHT differ by less than TOLERANCE."
  (< (abs (- left right)) tolerance))

(deftest zero-state
  (let ((state (make-zero-state 2)))
    (ok (equalp (amplitudes state)
                #(#C(1.0d0 0.0d0)
                  #C(0.0d0 0.0d0)
                  #C(0.0d0 0.0d0)
                  #C(0.0d0 0.0d0))))
    (ok (normalized-p state))))

(deftest single-qubit-gates
  (testing "X maps |0> to |1>"
    (let ((state (make-zero-state 1)))
      (x state 0)
      (ok (equalp (probabilities state) #(0.0d0 1.0d0)))))
  (testing "H creates an equal superposition"
    (let ((state (make-zero-state 1)))
      (h state 0)
      (ok (approximately= 0.5d0 (aref (probabilities state) 0)))
      (ok (approximately= 0.5d0 (aref (probabilities state) 1)))
      (ok (normalized-p state))))
  (testing "H applied twice interferes back to |0>"
    (let ((state (make-zero-state 1)))
      (h state 0)
      (h state 0)
      (ok (approximately= 1.0d0 (aref (probabilities state) 0)))
      (ok (approximately= 0.0d0 (aref (probabilities state) 1))))))

(deftest bell-state
  (let ((state (make-zero-state 2)))
    (h state 0)
    (cnot state 0 1)
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
                   (cl-user::measure 0))))
    (multiple-value-bind (state measurements)
        (run-circuit circuit)
      (ok (normalized-p state))
      (ok (= 1 (length measurements))))))

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
