#lang racket/base

(require rackunit
         "../aloe/eval.rkt"
         "../aloe/main.rkt")

(define tree-program
  #<<ALOE
(define-class (Tree T)
  (constructors
    (Leaf (fields (value T)))
    (Branch (fields (left (Tree T)) (right (Tree T)))))
  (methods
    (size () Int
      (self case
        (Leaf (value) 1)
        (Branch (left right)
          ((left size) + (right size)))))))
ALOE
  )

(define checker-environment (make-type-environment))
(void (typecheck-source tree-program checker-environment))

;; Recursive constructor fields preserve and constrain the class argument.
(check-equal?
 (type->datum
  (typecheck-source "(Tree Leaf 1)" checker-environment))
 '(Tree Int))
(check-equal?
 (type->datum
  (typecheck-source
   "(Tree Branch (Tree Leaf 1) (Tree Leaf 2))"
   checker-environment))
 '(Tree Int))
(check-equal?
 (type->datum
  (typecheck-source
   "((Tree Branch (Tree Leaf 1) (Tree Leaf 2)) size)"
   checker-environment))
 'Int)

(define environment (make-top-level-env))
(void (eval-source tree-program environment))

;; Recursive method sends run on payloads bound by the matching case clause.
(define leaf (eval-source "(Tree Leaf 1)" environment))
(check-true (instance-value? leaf))
(check-eq? (instance-value-constructor leaf) 'Leaf)
(check-equal? (eval-source "((Tree Leaf 1) size)" environment) 1)

(define branch
  (eval-source
   "(Tree Branch (Tree Leaf 1) (Tree Leaf 2))"
   environment))
(check-true (instance-value? branch))
(check-eq? (instance-value-constructor branch) 'Branch)
(check-equal?
 (eval-source
  "((Tree Branch (Tree Leaf 1) (Tree Leaf 2)) size)"
  environment)
 2)
(check-equal?
 (eval-source
  #<<ALOE
((Tree Branch
   (Tree Branch (Tree Leaf 1) (Tree Leaf 2))
   (Tree Leaf 3))
 size)
ALOE
  environment)
 3)

;; Both constructors must be covered in a method case.
(check-exn
 #rx"missing constructors: \\(Branch\\)"
 (lambda ()
   (typecheck-source
    #<<ALOE
(define-class (LeafOnlyTree T)
  (constructors
    (Leaf (fields (value T)))
    (Branch
      (fields
        (left (LeafOnlyTree T))
        (right (LeafOnlyTree T)))))
  (methods
    (size () Int
      (self case
        (Leaf (value) 1)))))
ALOE
    (make-type-environment))))
(check-exn
 #rx"missing constructors: \\(Leaf\\)"
 (lambda ()
   (typecheck-source
    #<<ALOE
(define-class (BranchOnlyTree T)
  (constructors
    (Leaf (fields (value T)))
    (Branch
      (fields
        (left (BranchOnlyTree T))
        (right (BranchOnlyTree T)))))
  (methods
    (size () Int
      (self case
        (Branch (left right)
          ((left size) + (right size)))))))
ALOE
    (make-type-environment))))

;; Branch children must instantiate the same recursive Tree type.
(check-exn
 #rx"inconsistent type parameter T|constructor field type mismatch"
 (lambda ()
   (typecheck-source
    "(Tree Branch (Tree Leaf 1) (Tree Leaf 2.0))"
    checker-environment)))

;; Constructor arity is checked before a value can be bound.
(check-exn
 #rx"arity error for Branch: expected 2 argument"
 (lambda ()
   (typecheck-source
    "(define t (Tree Branch))"
    checker-environment)))
