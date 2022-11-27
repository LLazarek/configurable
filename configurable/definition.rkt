#lang at-exp racket/base

(provide (all-from-out "private/configurable-definition.rkt"))
(require "private/configurable-definition.rkt")

(module reader syntax/module-reader configurable/definition)

