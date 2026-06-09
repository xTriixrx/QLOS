(in-package #:qlos)

;; Keep amplitudes unboxed and contiguous.  Gate kernels repeatedly scan this
;; array, so a specialized representation avoids storing generic Lisp objects.
(deftype amplitude-vector ()
  '(simple-array (complex double-float) (*)))

(defstruct (quantum-state
             (:constructor %make-quantum-state (qubit-count amplitudes))
             (:copier nil))
  "An ideal pure state for a fixed-size quantum register.

QUBIT-COUNT determines the register width.  AMPLITUDES contains one complex
value for each computational basis state and therefore has length 2^N.  The
public constructor and copier are defined separately so they can preserve this
relationship."
  ;; Slot initforms must satisfy their declared types even though the private
  ;; constructor always supplies both values explicitly.
  (qubit-count 1 :type (integer 1 *) :read-only t)
  (amplitudes (make-array 0 :element-type '(complex double-float))
              :type amplitude-vector))

(defun make-zero-state (qubit-count)
  "Create a QUBIT-COUNT register initialized to the all-zero basis state.

The returned state owns a specialized complex double-float array of length
2^QUBIT-COUNT.  Its first amplitude is one and every other amplitude is zero."
  (check-type qubit-count (integer 1 *))
  ;; Shifting 1 left by QUBIT-COUNT computes the required 2^N amplitudes.
  (let ((values (make-array (ash 1 qubit-count)
                            :element-type '(complex double-float)
                            :initial-element #C(0.0d0 0.0d0))))
    ;; Array index zero represents the all-zero computational basis state.
    (setf (aref values 0) #C(1.0d0 0.0d0))
    (%make-quantum-state qubit-count values)))

(defun copy-quantum-state (state)
  "Return an independent copy of STATE.

Gate and measurement functions mutate states in place.  This function is
therefore useful when several executions must begin from the same state."
  (%make-quantum-state
   (quantum-state-qubit-count state)
   (copy-seq (quantum-state-amplitudes state))))

(defun qubit-count (state)
  "Return the fixed number of qubits represented by STATE."
  (quantum-state-qubit-count state))

(defun amplitudes (state)
  "Return a copy of STATE's computational-basis amplitude vector.

The copy prevents callers from bypassing the simulator's state update
functions.  Qubit zero is represented by the least-significant index bit."
  (copy-seq (quantum-state-amplitudes state)))

(defun probabilities (state)
  "Return the observation probability of each basis state in STATE.

Each result is the squared magnitude of the corresponding complex amplitude.
The returned array is newly allocated and can be modified by the caller."
  (map '(simple-array double-float (*))
       (lambda (amplitude)
         ;; A complex value multiplied by its conjugate yields its real,
         ;; nonnegative squared magnitude.
         (coerce (realpart (* amplitude (conjugate amplitude)))
                 'double-float))
       (quantum-state-amplitudes state)))

(defun normalized-p (state &key (tolerance 1.0d-12))
  "Return true when STATE's probabilities sum to one within TOLERANCE.

TOLERANCE accommodates floating-point error introduced by repeated gate
applications."
  (<= (abs (- 1.0d0 (reduce #'+ (probabilities state))))
      tolerance))

(defun %check-qubit (state qubit)
  "Signal an error unless QUBIT is a valid zero-based index into STATE."
  (check-type qubit (integer 0 *))
  (unless (< qubit (quantum-state-qubit-count state))
    (error "Qubit ~D is outside a ~D-qubit register."
           qubit (quantum-state-qubit-count state))))

(defun measure (state qubit &optional (random-state *random-state*))
  "Measure QUBIT in STATE and return the sampled bit, either zero or one.

STATE is mutated to the corresponding collapsed and renormalized state.
RANDOM-STATE controls sampling and may be supplied for reproducible callers."
  (%check-qubit state qubit)
  (let* ((values (quantum-state-amplitudes state))
         ;; The selected bit in each array index identifies whether that basis
         ;; state contributes to the qubit-zero or qubit-one outcome.
         (mask (ash 1 qubit))
         (probability-one
           (loop for index below (length values)
                 when (logtest mask index)
                   sum (let ((value (aref values index)))
                         (realpart (* value (conjugate value))))
                     into total
                 finally (return (coerce total 'double-float))))
         ;; Sampling a uniform value below P(1) implements the two-outcome
         ;; probability distribution without constructing another collection.
         (result (if (< (random 1.0d0 random-state) probability-one) 1 0))
         (result-probability (if (zerop result)
                                 (- 1.0d0 probability-one)
                                 probability-one)))
    (when (<= result-probability 0.0d0)
      (error "Cannot collapse onto a zero-probability measurement result."))
    ;; Removing the incompatible amplitudes leaves total probability
    ;; RESULT-PROBABILITY.  Dividing amplitudes by its square root restores a
    ;; total probability of one.
    (let ((scale (/ 1.0d0 (sqrt result-probability))))
      (loop for index below (length values)
            for bit = (if (logtest mask index) 1 0)
            do (setf (aref values index)
                     (if (= bit result)
                         (* (aref values index) scale)
                         #C(0.0d0 0.0d0)))))
    result))
