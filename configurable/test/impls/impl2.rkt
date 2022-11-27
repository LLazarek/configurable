#lang racket

(provide select-mutants all-mutants-should-have-trails?
         pre-selected-mutant-samples-db)

(define select-mutants 2)
(define (all-mutants-should-have-trails?) (pre-selected-mutant-samples-db))

(define pre-selected-mutant-samples-db (make-parameter 2))
