#lang racket

(require "../configurables.rkt")

(provide f)

(define (f x)
  (* (configured:n) x))
