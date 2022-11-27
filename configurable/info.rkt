#lang info

(define collection "configurable")
(define build-deps '("racket-doc" "scribble-lib" "at-exp-lib"))
(define deps '("base"
               "git://github.com/llazarek/ruinit.git"))
(define pkg-desc "A simple software configuration system")
(define scribblings '(("scribblings/configurable.scrbl")))
(define pkg-authors '(lukas))
