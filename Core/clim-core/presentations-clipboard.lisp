(in-package :clim-internals)

(define-presentation-generic-function %convert-clipboard-content convert-clipboard-content
  (type-key parameters options object type output-type check-only))

(define-presentation-method convert-clipboard-content (obj (type t) output-type check-only)
  nil)

(define-presentation-method convert-clipboard-content (obj (type string) (output-type (eql :string)) check-only)
  (check-type obj string)
  obj)

(defun convert-clipboard-content (obj output-type &key type check-only)
  (funcall-presentation-generic-function convert-clipboard-content
                                         obj
                                         (or type (presentation-type-of obj))
                                         output-type
                                         check-only))

(defun supported-clipboard-types (obj type)
  (loop
    for output-type in '(:string :html)
    when (convert-clipboard-content obj output-type :type type :check-only t)
      collect type))

(clim:define-presentation-method convert-clipboard-content
    (obj (type selection-content) (output-type (eql :string)) check-only)
  (selection-content/text obj))

(clim:define-presentation-method convert-clipboard-content
    (obj (type selection-content) (output-type (eql :html)) check-only)
  (selection-content/html obj))