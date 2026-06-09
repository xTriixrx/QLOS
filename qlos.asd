(asdf:defsystem "qlos"
  :version "0.1.0"
  :author "Vincent Nigro"
  :license ""
  :description "A Common Lisp quantum runtime for executing quantum programs"
  :serial t
  :components ((:module "src"
                :components
                ((:file "package")
                 (:file "state")
                 (:file "gates")
                 (:file "circuit")
                 (:file "benchmark"))))
  :in-order-to ((asdf:test-op (asdf:test-op "qlos/tests"))))

(asdf:defsystem "qlos/tests"
  :author "Vincent Nigro"
  :license ""
  :depends-on ("qlos" "rove")
  :serial t
  :components ((:module "tests"
                :components
                ((:file "package")
                 (:file "simulator"))))
  :perform (asdf:test-op (op component)
             (declare (ignore op component))
             (uiop:symbol-call :rove :run :qlos/tests)))
