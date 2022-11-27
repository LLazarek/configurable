#lang scribble/manual

@(require scribble/core)

@;;;;;;;;;;;;;;;@
@; Boilerplate ;@
@;;;;;;;;;;;;;;;@

@(require (for-label racket (only-in configurable/definition define-configurable define-implementation) (only-in configurable/config configure! configure-all!))
          scribble/example)

@(define configurable-eval (make-base-eval))
@examples[#:eval configurable-eval #:hidden (require racket configurable/definition configurable/config)]

@title{Configurable}
@author[(author+email "Lukas Lazarek" "lukas.lazarek@eecs.northwestern.edu"
#:obfuscate? #t)]

This library implements a simple system for software configuration.
The idea is that the system implementor can create configurable features which have multiple implementations that users can select from.
Users can then create a config that selects an implementation for each configurable feature.
The system can install such a config to configure the features.

This library supports that workflow with the following design.

First, the system implementor writes a @deftech{configurable feature set definition}, specifying each feature with
@itemize[
@item{an interface of values related to the feature}
@item{one or more implementations, identified by module paths.}
]
This definition is written in the @tt{#lang configurable/define} DSL.

With the configurable feature set definition in hand, the system implementor can @racket[require] it to access each feature's interface through parameters holding their currently configured values.

A @deftech{config} defines a mapping from each feature's interface to concrete values by selecting an implementation for each feature.
The system sets the current configuration values by installing a config with @racket[install-configuration!].
Configs are written in the @tt{#lang configurable/config} DSL.



@section{A tour by example}

This example illustrates implementing a tool that searches text by lines (think @tt{grep}).
The tool should allow users to select a search algorithm from three choices: literal matching, regexp, and fuzzy search (at least initially - we will see how the this library makes it easy to add more down the road).


Our tool's implementation might initially look like this.

@codeblock|{
;; tool.rkt
#lang racket

;; swap out with regexp.rkt or fuzzy.rkt
(require "literal.rkt")

(module+ main
  (require racket/cmdline)
  (define-values {query files-to-search}
    (command-line
      #:args [query . files-to-search]
      (values query files-to-search)))
  (search! query files-to-search))
}|

With the different search styles implemented in their own files.

@codeblock|{
;; literal.rkt
#lang racket

(provide (rename-out [search/literal! search!]))

(define (search/literal! str files)
  ;; todo...
  (displayln 'searching-literally))
}|

@codeblock|{
;; regexp.rkt
#lang racket

(provide (rename-out [search/regexp! search!]))

(define (search/regexp! rx files)
  ;; todo...
  (displayln 'searching-for-regexp))
}|

@codeblock|{
;; fuzzy.rkt
#lang racket

(provide (rename-out [search/fuzzy! search!]))

(define (search/fuzzy! pat files)
  ;; todo...
  (displayln 'searching-fuzzily))
}|


To let users select a search style via a config file instead of modifying the tool, we'll write a @tech{configurable feature set definition} describing our configurable feature (the search style) and our known implementations.
Then we'll write a @tech{config} that selects a style, which users can edit instead of editing the tool itself.

The feature set definition looks like this.

@codeblock|{
;; configurables.rkt
#lang configurable/definition

(define-configurable search-style
  #:provides [search!]

  (define-implementation literal
    #:module "literal.rkt")

  (define-implementation regexp
    #:module "regexp.rkt")

  (define-implementation fuzzy
    #:module "fuzzy.rkt"))
}|



And a @tech{config} file looks like this.

@codeblock|{
;; search-config.rkt
#lang configurable/config "configurables.rkt"

;; `fuzzy` here is bound by the definition in configurables.rkt
(configure-all! [search-style fuzzy])
}|


Finally we refactor our tool to look like this.
Each change is annotated with a comment.

@codeblock|{
;; tool.rkt
#lang racket

(require "configurables.rkt") ;; require the feature set definition

(module+ main
  (require racket/cmdline)
  (define-values {query files-to-search}
    (command-line
      ;; obtain the config path...
      #:once-each
      [("--config" "-c")
       path
       "search style configuration to use"
       ;; ... and install it
       (install-configuration! path)]
      #:args [query . files-to-search]
      (values query files-to-search)))
  ;; access the configured search function with the parameter `configured:search!`
  ;; which is created by `define-configurable!`
  ((configured:search!) query files-to-search))
}|


Under the hood, what's happening is that @racket[install-configuration!] sets the value of the parameter @tt{configured:search!}.


Of course, this example is a bit contrived because a single command-line switch would suffice to configure the search style.
However, that approach quickly grows unwieldy when there are several features to configure, and especially so if some implementations themselves may be parameterized.

This library offers a natural solution for the second challenge of parameterized features as well, with @deftech{implementation parameters}.
Implementation parameters are essentially arguments that can be specified in a @tech{config} file to configure an implementation.

Let's see how that works by adding a new feature to our search tool.
We'll support abbreviations in literal search queries, so that doing a literal search for @tt|{@myemail}| instead searches for @tt|{joe-schmoe9000@gmail.com}|.
A table of abbreviation definitions in the user's config file will define the set of these to use.


First, let's update literal.rkt to support these abbrevs.

@codeblock|{
;; literal.rkt
#lang racket

(provide (rename-out [search/literal! search!])
         current-abbrevs)

(define current-abbrevs (make-parameter (hash)))
(define (search/literal! str files)
  ;; todo...
  (displayln 'searching-literally/with-abbrevs)
  (displayln (current-abbrevs)))
}|


Next, let's update the configurable feature set definition.

@codeblock|{
;; configurables.rkt
#lang configurable/definition

(define-configurable search-style
  #:provides [search!]

  (define-implementation literal
    #:module "literal.rkt"
    #:parameters [current-abbrevs])

  (define-implementation regexp
    #:module "regexp.rkt")

  (define-implementation fuzzy
    #:module "fuzzy.rkt"))
}|


And finally we can use it in the config.

@codeblock|{
;; search-config.rkt
#lang configurable/config "configurables.rkt"

(configure-all! [search-style literal (hash "@myemail" "joe-schmoe9000@gmail.com")])
}|

The config would not need to change at all for other search styles, on the other hand.
For instance, the same fuzzy-searching config we had before is still valid now.



@section[#:tag "cfsd-dsl"]{Configurable feature set definition DSL}
@defmodule[configurable/definition #:lang]

@tech{configurable feature set definition}s are written in this language, and consist of a sequence of @racket[define-configurable] forms at the top level.

The resulting module provides the names of all the defined configurable features, the features @tt{configured:} parameters, and the operations on configs described in @secref{config-operations}.

@defform[
(define-configurable feature-id
  #:provides [id ...]

  implementation-definition ...)
]{
Defines a configurable feature named @racket[feature-id] which has several possible implementations, all of which provide the same set of @racket[id]s.

Each @racket[implementation-definition] must be an @racket[define-implementation] form.

This form creates and provides a parameter for each @racket[id] named @tt{configured:id} which will hold the currently configured implementation's version of @racket[id].
}

@defform[
(define-implementation implementation-id
  #:module relative-module-path
  maybe-parameters)

#:grammar [(maybe-parameters (code:line) (code:line #:parameters [parameter-id ...]))]
]{
Defines an implementation named @racket[implementation-id] found at @racket[relative-module-path].
Using the @racket[define-implementation] form outside of @racket[define-configurable] is a syntax error.

Each @racket[parameter-id] specified defines an @tech{implementation parameter}.

}



@section{Config DSL}
@defmodule[configurable/config #:lang]

@tech{config}s are written in this language, which is parameterized by the @tech{configurable feature set definition} whose relative path is provided after the @tt{#lang} (see the example configs above).
Configs consist of a sequence of @racket[configure!] or @racket[configure-all!] forms at the top level.

@defform[
(configure! feature-id implementation-id parameter-value ...)
]{
Specifies to use the named implementation for the named feature, with the given values for that implementation's @tech{implementation parameter}s (by position), if any.
}

@defform[
(configure-all! [feature-id implementation-id parameter-value ...] ...)
]{
Equivalent to a sequence of @racket[configure!]s.
}



@section[#:tag "config-operations"]{Config operations}
@defmodule[configurable/definition]

These operations are also provided by every @tech{configurable feature set definition}, which is the more typical way to obtain them.

@defproc[(install-configuration! [path path-string?]) any]{
Installs the given @tech{config}, setting the @tt{configured:} parameters of all the features specified therein.
(See @secref{cfsd-dsl}.)
}

@defproc[(call-with-configuration [path path-string?] [thunk (-> any)]) any]{
Calls @racket[thunk] with the given @tech{config} installed while in the dynamic extent of the call.
}

@defproc[(current-configuration-path) (or/c path-string? #f)]{
Returns the currently installed configuration path.
}
