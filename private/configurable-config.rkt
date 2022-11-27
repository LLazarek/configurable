#lang at-exp racket/base

(provide configure!
         configure-all!
         current-configuration-path
         install-configuration!
         call-with-configuration
         (rename-out [config:#%module-begin #%module-begin])
         (except-out (all-from-out racket/base) #%module-begin))

(require racket/contract
         racket/format
         racket/runtime-path
         syntax/parse/define
         (for-syntax racket/base
                     racket/syntax
                     racket/path
                     racket/format
                     syntax/location))

(define-for-syntax definitions-require-path-box (box #f))
(define-simple-macro (config:#%module-begin definitions-require-path body ...)
  #:with req (datum->syntax this-syntax (list 'require #'definitions-require-path))
  #:with install! (datum->syntax this-syntax 'install!)
  #:with prov (datum->syntax this-syntax '(provide install!))
  #:do [(set-box! definitions-require-path-box #'definitions-require-path)]
  (#%module-begin
   req
   prov
   (define (install!)
     body ...)))

(define-simple-macro (configure! configurable:id implementation:id parameter-value ...)
  ;; local-require so that different configurables can have implementations with the same name
  #:with parameter-require-expr
  (datum->syntax #'configurable
                 `(local-require (submod ,(unbox definitions-require-path-box) ,#'configurable)))
  (begin
    (let ()
      parameter-require-expr
      (implementation parameter-value ...))))

(define-simple-macro (configure-all! [clause-parts ...] ...)
  (begin (configure! clause-parts ...) ...))

(define current-configuration-path/private (make-parameter #f))
(define (current-configuration-path) (current-configuration-path/private))

(define (install-configuration! path)
  (define path-string (~a path))
  (current-configuration-path/private path-string)
  ;; All configuration is done by a function instead of just at the module top
  ;; level to allow configs to be installed more than once.
  ;; E.g. this should work: install A, install B, install A
  ((dynamic-require `(file ,path-string) 'install!)))

(define (call-with-configuration configuration-path
                                 thunk)
  (define old-config (current-configuration-path/private))
  (dynamic-wind (λ _ (install-configuration! configuration-path))
                thunk
                (λ _ (when old-config
                       (install-configuration! old-config)))))
