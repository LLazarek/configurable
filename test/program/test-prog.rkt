#lang racket

(require "../configurables.rkt"
         ruinit)

(test-begin
  #:name config1
  (ignore (install-configuration! "../configs/config1.rkt"))
  (test-equal? (configured:select-mutants) 0)
  (test-equal? (configured:all-mutants-should-have-trails?) 0))

(test-begin
  #:name config2
  (ignore (install-configuration! "../configs/config2.rkt"))
  (test-equal? (configured:select-mutants) 2)
  (test-equal? ((configured:all-mutants-should-have-trails?)) 52))

