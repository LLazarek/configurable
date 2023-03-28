#lang racket

(provide select-mutants all-mutants-should-have-trails?
         pre-selected-mutant-samples-db)

(require "../program/test-lib.rkt")

(define select-mutants (f 2))
(define (all-mutants-should-have-trails?) (pre-selected-mutant-samples-db))

(define pre-selected-mutant-samples-db (make-parameter 2))
