(in-package :clim-mezzano)

(defvar *last-mouse-x* 0)
(defvar *last-mouse-y* 0)
(defvar *last-mouse-sheet* nil)
(defvar *last-modifier-state* 0)

(defvar *char->name* (make-hash-table :test #'eql))

;;;======================================================================
;;;
;;; mez-event->mcclim-event - converts mezzano events to mcclim events
;;;
;;;======================================================================

(defgeneric mez-event->mcclim-event (mcclim-fifo event))

(defmethod mez-event->mcclim-event (mcclim-fifo event)
  ;; Default cause - log event and ignore
  (debug-format "mcclim backend unexpected event")
  (debug-format "    ~S" event)
  (values nil nil))

;;;======================================================================
;;; Keyboard Events
;;;======================================================================

(defun get-name (char)
  (let ((name (gethash char *char->name*)))
    (if name
        name
        (setf (gethash char *char->name*) (intern (string char) :keyword)))))

(defparameter +modifier-to-clim-alist+
  `((:shift    . ,+shift-key+)
    (:control  . ,+control-key+)
    (:meta     . ,+meta-key+)
    (:super    . ,+super-key+)))

(defun compute-modifier-state (modifier-keys)
  (let ((modifier 0))
    (dolist (key modifier-keys)
      (let ((modifier-info (assoc key +modifier-to-clim-alist+)))
        (if modifier-info
            (setf modifier (logior modifier (cdr modifier-info)))
            (debug-format "Unknown modifier key ~S" key))))
    (setf *last-modifier-state* modifier)))

(defmethod mez-event->mcclim-event (mcclim-fifo (event key-event))
  ;; (debug-format "key-event")
  ;; (debug-format "    ~S" (mezzano.gui.compositor::key-scancode event))
  ;; (debug-format "    ~S" (mezzano.gui.compositor::key-releasep event))
  ;; (debug-format "    ~S" (mezzano.gui.compositor::key-key event))
  ;; (debug-format "    ~S"
  ;;               (mezzano.gui.compositor::key-modifier-state event))
  (let* ((releasep (mezzano.gui.compositor::key-releasep event))
         (char (mezzano.gui.compositor::key-key event))
         (name (get-name char))
         (modifier-state (compute-modifier-state (mezzano.gui.compositor::key-modifier-state event))))
    (mezzano.supervisor:fifo-push
     (make-instance (if releasep 'key-release-event 'key-press-event)
                    :key-name name
                    :key-character char
                    :x *last-mouse-x*
                    :y *last-mouse-y*
                    :graft-x 0
                    :graft-y 0
                    :sheet *current-focus*
                    :modifier-state modifier-state)
     mcclim-fifo
     nil)))

;;;======================================================================
;;; Pointer Events
;;;======================================================================

(defun compute-mouse-buttons (buttons)
  (let ((result 0))
    ;; bit 0 -> bit 0
    (setf (ldb (byte 1 0) result) (ldb (byte 1 0) buttons))
    ;; bit 2 -> bit 1
    (setf (ldb (byte 1 1) result) (ldb (byte 1 2) buttons))
    ;; bit 1 -> bit 2
    (setf (ldb (byte 1 2) result) (ldb (byte 1 1) buttons))
    result))

(defun pointer-motion-event (mcclim-fifo sheet event)
  (let ((time 0))
    (mezzano.supervisor:fifo-push
     (make-instance 'pointer-motion-event
                    :pointer 0
                    :x *last-mouse-x*
                    :y *last-mouse-y*
                    :graft-x 0
                    :graft-y 0
                    :sheet sheet
                    :modifier-state *last-modifier-state*
                    :timestamp time)
     mcclim-fifo
     nil)))

(defun pointer-button-event (mcclim-fifo sheet event)
  (let* ((buttons (compute-mouse-buttons
                   (mezzano.gui.compositor::mouse-button-state event)))
         (change (compute-mouse-buttons
                  (mezzano.gui.compositor::mouse-button-change event)))
         (time 0))
    (mezzano.supervisor:fifo-push
     (make-instance (if (= (logand buttons change) 0)
                        'pointer-button-release-event
                        'pointer-button-press-event)
                    :pointer 0
                    :button buttons
                    :x *last-mouse-x*
                    :y *last-mouse-y*
                    :graft-x 0
                    :graft-y 0
                    :sheet sheet
                    :modifier-state *last-modifier-state*
                    :timestamp time)
     mcclim-fifo
     nil)))

(defun mouse-exit-event (mcclim-fifo sheet event)
  (debug-format "mouse-exit-event")
  (debug-format "    ~S" sheet)
  (let ((time 0))
    (mezzano.supervisor:fifo-push
    (make-instance 'pointer-exit-event
                   :pointer 0
                   :x *last-mouse-x*
                   :y *last-mouse-y*
                   :graft-x 0
                   :graft-y 0
                   :sheet sheet
                   :modifier-state *last-modifier-state*
                   :timestamp time)
    mcclim-fifo
    nil)))

(defun mouse-enter-event (mcclim-fifo sheet event)
  (debug-format "mouse-enter-event")
  (debug-format "    ~S" sheet)
  (let ((time 0))
    (mezzano.supervisor:fifo-push
     (make-instance 'pointer-enter-event
                    :pointer 0
                    :x *last-mouse-x*
                    :y *last-mouse-y*
                    :graft-x 0
                    :graft-y 0
                    :sheet sheet
                    :modifier-state *last-modifier-state*
                    :timestamp time)
     mcclim-fifo
     nil)))

(defun frame-mouse-event (mcclim-fifo sheet mez-frame event)
  (handler-case
      (progn
        (mezzano.gui.widgets:frame-mouse-event mez-frame event)
        (values nil nil))
    (mezzano.gui.widgets:close-button-clicked ()
      (mezzano.supervisor:fifo-push
       (make-instance 'window-manager-delete-event :sheet sheet)
       mcclim-fifo
       nil))))

(defmethod mez-event->mcclim-event (mcclim-fifo (event mouse-event))
  ;; (debug-format "mouse-event")
  ;; (debug-format "    ~S" (mezzano.gui.compositor::mouse-button-state event))
  ;; (debug-format "    ~S" (mezzano.gui.compositor::mouse-button-change event))
  ;; (debug-format "    ~S" (mezzano.gui.compositor::mouse-x-position event))
  ;; (debug-format "    ~S" (mezzano.gui.compositor::mouse-y-position event))
  ;; (debug-format "    ~S" (mezzano.gui.compositor::mouse-x-motion event))
  ;; (debug-format "    ~S" (mezzano.gui.compositor::mouse-y-motion event))

  (let* ((mez-window (mezzano.gui.compositor::window event))
         (mouse-x    (mezzano.gui.compositor::mouse-x-position event))
         (mouse-y    (mezzano.gui.compositor::mouse-y-position event))
         (mez-mirror (port-lookup-mirror *port* mez-window))
         (sheet      (port-lookup-sheet *port* mez-window)))
    (with-slots (mez-frame dx dy width height) mez-mirror
      (cond ((or (null mez-frame)
                 (<= mouse-x dx) (>= mouse-x width)
                 (<= mouse-y dy) (>= mouse-y height))
             (setf *last-mouse-x* mouse-x
                   *last-mouse-y* mouse-y)
             (when *last-mouse-sheet*
               (mouse-exit-event mcclim-fifo *last-mouse-sheet* event)
               (setf *last-mouse-sheet* nil))
             (frame-mouse-event mcclim-fifo sheet mez-frame event))

            ((= (mezzano.gui.compositor::mouse-button-change event) 0)
             (setf *last-mouse-x* (- mouse-x dx)
                   *last-mouse-y* (- mouse-y dy))
             (cond ((eq sheet *last-mouse-sheet*)
                    (pointer-motion-event mcclim-fifo sheet event))
                   (T
                    (when *last-mouse-sheet*
                      (mouse-exit-event mcclim-fifo *last-mouse-sheet* event))
                    (mouse-enter-event mcclim-fifo sheet event)
                    (setf *last-mouse-sheet* sheet))))
            (T
             (setf *last-mouse-x* (- mouse-x dx)
                   *last-mouse-y* (- mouse-y dy))
             (unless (eq sheet *last-mouse-sheet*)
               (when *last-mouse-sheet*
                 (mouse-exit-event mcclim-fifo *last-mouse-sheet* event))
               (mouse-enter-event mcclim-fifo sheet event)
               (setf *last-mouse-sheet* sheet))
             (pointer-button-event mcclim-fifo sheet event))))))

;;;======================================================================
;;; Activation Events
;;;======================================================================

(defmethod mez-event->mcclim-event (mcclim-fifo (event window-activation-event))
  (let* ((mez-window (mezzano.gui.compositor::window event))
         (mez-mirror (port-lookup-mirror *port* mez-window))
         (mez-frame (slot-value mez-mirror 'mez-frame))
         (sheet (mez-window->sheet mez-window))
         (focus (frame-query-io (pane-frame sheet))))
    ;; (debug-format "window-activation-event - not implemented")
    ;; (debug-format "    ~S" mez-window)
    ;; (debug-format "    ~S" (mezzano.gui.compositor::state event))
    ;; (debug-format "    ~S" sheet)

    (setf (mezzano.gui.widgets:activep mez-frame)
          (mezzano.gui.compositor::state event)
          *current-focus* focus)
    (mezzano.gui.widgets:draw-frame mez-frame)))

(defmethod mez-event->mcclim-event (mcclim-fifo (event quit-event))
  ;; (debug-format "quit-event")
  (mezzano.supervisor:fifo-push
   (make-instance 'window-destroy-event
                  :sheet *current-focus*
                  :region nil)
   mcclim-fifo
   nil))

(defmethod mez-event->mcclim-event (mcclim-fifo (event window-close-event))
  (debug-format "window-close-event - ignored (?)")
  (values nil nil))
