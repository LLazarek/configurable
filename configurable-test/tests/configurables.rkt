#lang configurable/definition

(define-configurable mutant-sampling
  #:provides [select-mutants all-mutants-should-have-trails?]

  (define-implementation none
    #:module "impls/impl1.rkt")

  (define-implementation use-pre-selected-samples
    #:module "impls/impl2.rkt"
    #:parameters [pre-selected-mutant-samples-db]))
