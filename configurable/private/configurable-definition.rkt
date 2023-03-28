#lang at-exp racket/base

(provide define-configurable
         define-implementation
         (rename-out [def-modbegin #%module-begin])
         (except-out (all-from-out racket/base) #%module-begin))

(require racket/contract
         racket/format
         racket/runtime-path
         syntax/parse/define
         (for-syntax racket/base
                     racket/syntax
                     racket/path
                     racket/format
                     syntax/location)
         (except-in "configurable-config.rkt" #%module-begin))

(define-simple-macro (def-modbegin forms ...)
  (#%module-begin
   (provide 
    current-configuration-path
    install-configuration!
    call-with-configuration)
   forms ...))

(define-simple-macro (define-configurable name
                       #:provides [provided-value:id ...]
                       {~and body ({~literal define-implementation} impl-name . impl-body)} ...)
  #:with [provided-param ...] (for/list ([provided-id (in-list (attribute provided-value))])
                                (format-id this-syntax "configured:~a" provided-id))
  #:with install-params! (datum->syntax #'name 'install-params!)
  #:with provides (datum->syntax #'name 'provides)
  (begin
    (define provided-param (make-parameter #f)) ...
    (provide provided-param ...)
    (module+ name
      (module+ provides (provide provided-param ...))
      #;(define (install-params! mod-path)
          (provided-param (dynamic-require `(file ,mod-path) 'provided-value))
          ...)
      (define-implementation name impl-name
        #:internal-provide-info [[provided-value provided-param] ...]
        . impl-body) ...
      (provide impl-name) ...)))

(define-simple-macro (define-implementation configurable-name name
                       #:internal-provide-info [[local-id provided-parameter-id] ...]
                       #:module path-expr
                       ;; lltodo: contracts should be specified here too
                       {~alt {~optional {~seq #:parameters [parameter:id ...]}
                                        #:defaults ([(parameter 1) '()])}
                             {~optional {~seq #:fixed-parameters ([config-parameter:id config-parameter-expr] ...)}
                                        #:defaults ([(config-parameter 1) '()]
                                                    [(config-parameter-expr 1) '()])}}
                       ...)
  #:with install-params! (datum->syntax #'name 'install-params!)
  #:with [local-parameter ...] (map (λ (p)
                                      (format-id #'name "local:~a" p))
                                    (attribute parameter))
  #:with name-mpi (format-id #'name "mpi:~a" #'name)
  #:with path (datum->syntax #'here (syntax->datum #'path-expr))
  (begin
    (define-runtime-module-path-index name-mpi path)
    (define (name {~? {~@ local-parameter ...}})
      ((dynamic-require name-mpi 'config-parameter) config-parameter-expr) ...
      ((dynamic-require name-mpi 'parameter) local-parameter) ...
      (provided-parameter-id (dynamic-require name-mpi 'local-id)) ...)))
