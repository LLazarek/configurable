#lang at-exp racket/base

(provide (all-from-out "private/configurable-config.rkt"))
(require "private/configurable-config.rkt")

(module reader syntax/module-reader configurable/config)

