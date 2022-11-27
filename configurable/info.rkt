#lang info

(define collection "configurable")
(define build-deps '("racket-doc" "scribble-lib" "at-exp-lib"))
(define deps '("base"
               "git://github.com/llazarek/ruinit.git"))
(define scribblings '(("scribblings/configurable.scrbl")))
