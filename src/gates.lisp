(in-package #:qlos)

(defun %apply-single-qubit-gate (state qubit m00 m01 m10 m11)
  "Apply a 2x2 matrix to QUBIT in STATE and return the mutated STATE.

M00, M01, M10, and M11 are the matrix entries in row-major order.  The
implementation visits pairs of amplitudes that differ only in QUBIT, allowing
the gate to act on an N-qubit state without constructing a 2^N by 2^N matrix."
  (%check-qubit state qubit)
  (let* ((values (quantum-state-amplitudes state))
         ;; In little-endian indexing, toggling QUBIT changes an array index by
         ;; 2^QUBIT.  Each block contains one zero-bit and one one-bit region.
         (stride (ash 1 qubit))
         (block-size (* 2 stride)))
    (loop for block-start from 0 below (length values) by block-size
          do (loop for offset below stride
                   for zero-index = (+ block-start offset)
                   for one-index = (+ zero-index stride)
                   ;; Save both old values before either array slot is changed;
                   ;; both matrix rows depend on the original amplitude pair.
                   for zero-amplitude = (aref values zero-index)
                   for one-amplitude = (aref values one-index)
                   do (setf (aref values zero-index)
                            (+ (* m00 zero-amplitude)
                               (* m01 one-amplitude))
                            (aref values one-index)
                            (+ (* m10 zero-amplitude)
                               (* m11 one-amplitude)))))
    state))

(defun x (state qubit)
  "Apply Pauli-X to QUBIT in STATE and return the mutated STATE.

The X matrix exchanges each amplitude pair whose basis indices differ only in
QUBIT."
  (%apply-single-qubit-gate
   state qubit
   #C(0.0d0 0.0d0) #C(1.0d0 0.0d0)
   #C(1.0d0 0.0d0) #C(0.0d0 0.0d0)))

(defun h (state qubit)
  "Apply the Hadamard gate to QUBIT in STATE and return the mutated STATE."
  (let* ((inverse-sqrt-two (/ 1.0d0 (sqrt 2.0d0)))
         ;; Keep every matrix entry in the same numeric domain as the
         ;; specialized complex double-float amplitude vector.
         (positive (complex inverse-sqrt-two 0.0d0))
         (negative (complex (- inverse-sqrt-two) 0.0d0)))
    (%apply-single-qubit-gate
     state qubit
     positive positive
     positive negative)))

(defun z (state qubit)
  "Apply Pauli-Z to QUBIT in STATE and return the mutated STATE.

The Z gate leaves the qubit-zero amplitude unchanged and negates the
qubit-one amplitude."
  (%apply-single-qubit-gate
   state qubit
   #C(1.0d0 0.0d0) #C(0.0d0 0.0d0)
   #C(0.0d0 0.0d0) #C(-1.0d0 0.0d0)))

(defun s (state qubit)
  "Apply the S phase gate to QUBIT in STATE and return the mutated STATE.

The S gate leaves the qubit-zero amplitude unchanged and multiplies the
qubit-one amplitude by i."
  (%apply-single-qubit-gate
   state qubit
   #C(1.0d0 0.0d0) #C(0.0d0 0.0d0)
   #C(0.0d0 0.0d0) #C(0.0d0 1.0d0)))

(defun t-gate (state qubit)
  "Apply the T phase gate to QUBIT in STATE and return the mutated STATE.

The T gate leaves the qubit-zero amplitude unchanged and multiplies the
qubit-one amplitude by exp(i*pi/4)."
  (let ((inverse-sqrt-two (/ 1.0d0 (sqrt 2.0d0))))
    (%apply-single-qubit-gate
     state qubit
     #C(1.0d0 0.0d0) #C(0.0d0 0.0d0)
     #C(0.0d0 0.0d0) (complex inverse-sqrt-two inverse-sqrt-two))))

(defun cnot (state control target)
  "Apply controlled-X to STATE and return the mutated STATE.

TARGET is flipped only for basis states whose CONTROL bit is one.  CONTROL and
TARGET must name distinct qubits."
  (%check-qubit state control)
  (%check-qubit state target)
  (when (= control target)
    (error "CNOT control and target must be different qubits."))
  (let ((values (quantum-state-amplitudes state))
        (control-mask (ash 1 control))
        (target-mask (ash 1 target)))
    (loop for index below (length values)
          ;; Restrict swaps to target-zero indices.  Visiting target-one
          ;; indices as well would encounter every pair twice and undo it.
          when (and (logtest control-mask index)
                    (not (logtest target-mask index)))
            ;; XOR toggles only the target bit, producing the paired basis
            ;; index while preserving all other qubits.
            do (let ((paired-index (logxor index target-mask)))
                 (rotatef (aref values index)
                          (aref values paired-index)))))
  state)
