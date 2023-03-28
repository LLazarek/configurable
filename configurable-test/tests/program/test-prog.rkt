#lang racket

(require "../configurables.rkt"
         "test-lib.rkt"
         ruinit)

(test-begin
  #:name config1
  (ignore (install-configuration! "../configs/config1.rkt"))
  (test-equal? (configured:select-mutants) 0)
  (test-equal? (configured:all-mutants-should-have-trails?) 0)
  (test-equal? (f 2) 10))

(test-begin
  #:name config2
  (ignore (install-configuration! "../configs/config2.rkt"))
  (test-equal? (configured:select-mutants) 10)
  (test-equal? ((configured:all-mutants-should-have-trails?)) 52)
  (test-equal? (f 2) 10))

