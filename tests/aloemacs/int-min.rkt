#lang racket/base

(require racket/runtime-path
         rackunit
         "../../aloe/driver.rkt"
         (only-in "../../aloe/type.rkt" exn:fail:aloe-type?))

(define-runtime-path editor-path "../../examples/aloemacs/editor.aloe")

(define (state-with-editor)
  (define state (make-driver))
  (driver-eval! state `(load ,(path->string editor-path)))
  state)

(test-case "editor no longer accepts clamp-column or max-zero"
  (define state (state-with-editor))
  (driver-eval! state
                '(define editor
                   (AloemacsEditor new
                     (Text from-string "ab\nc")
                     (Position new 0 2)
                     #f 0 0 (List empty) (if #t (Option None) (Option Some (Position new 0 0))))))
  (check-exn exn:fail:aloe-type?
             (lambda () (driver-eval! state '(editor clamp-column 2 (editor text)))))
  (check-exn exn:fail:aloe-type?
             (lambda () (driver-eval! state '(editor max-zero -1)))))

(test-case "vertical movement clamps with Int min"
  (define state (state-with-editor))
  (driver-eval! state
                '(define first
                   (AloemacsEditor new
                     (Text from-string "ab\nc")
                     (Position new 0 2)
                     #f 0 0 (List empty) (if #t (Option None) (Option Some (Position new 0 0))))))
  (driver-eval! state '(define second (first move-down)))
  (check-equal? (driver-eval! state '((second point) line)) 1)
  (check-equal? (driver-eval! state '((second point) column)) 1)
  (driver-eval! state '(define back (second move-up)))
  (check-equal? (driver-eval! state '((back point) line)) 0)
  (check-equal? (driver-eval! state '((back point) column)) 1))

(test-case "ensure-visible clamps a negative origin with Int max"
  (define state (state-with-editor))
  (driver-eval! state
                '(define editor
                   (AloemacsEditor new
                     (Text from-string "ab\nc")
                     (Position new 0 0)
                     #f -5 -5 (List empty) (if #t (Option None) (Option Some (Position new 0 0))))))
  (driver-eval! state '(define visible (editor ensure-visible 3 3)))
  (check-equal? (driver-eval! state '(visible scroll-row)) 0)
  (check-equal? (driver-eval! state '(visible scroll-col)) 0))
