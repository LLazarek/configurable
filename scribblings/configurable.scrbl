#lang scribble/manual

@(require scribble/core)

@;;;;;;;;;;;;;;;@
@; Boilerplate ;@
@;;;;;;;;;;;;;;;@

@(require (for-label racket (only-in configurable/definition define-configurable define-implementation) (only-in configurable/config configure-all!))
          scribble/example)

@(define configurable-eval (make-base-eval))
@examples[#:eval configurable-eval #:hidden (require racket configurable/definition configurable/config)]

@title{configurable}
@author{Lukas Lazarek}

This library implements a simple system for software configuration.
The idea is that the system implementor can create configurable features which have multiple implementations that users can select from.
Users can then create a config that selects an implementation for each configurable feature.
The system can install a config to configure the features.

This library supports that workflow with the following design.

First, the system implementor writes a @deftech{configurable feature set definition}, specifying each feature with
@itemize[
@item{an interface of values related to the feature}
@item{one or more implementations, identified by module paths.}
]
This definition is written in the @tt{#lang configurable/define} DSL.

With the configurable feature set definition in hand, the system implementor can @racket[require] it to access each feature's interface through parameters holding their currently configured values.

A @deftech{config} defines a mapping from each feature's interface to concrete values by selecting an implementation for each feature.
The system sets the current configuration values by installing a config with @racket[install-config!].
Configs are written in the @tt{#lang configurable/config} DSL.

@section{An example}

I am implementing a system that searches text by lines, and I want users to be able to select a search algorithm; perhaps I want to support literal matching, regex, and fuzzy search.
So I wrote three modules implementing the different algorithms, all sharing the same interface. For instance,
@racketblock[
((listof string?)  (code:comment "full text lines")
 string?           (code:comment "search query")
 . -> .
 (listof string?)) (code:comment "matching lines")
]
So now I have modules @tt{search/literal.rkt}, @tt{search/regex.rkt}, and @tt{search/fuzzy.rkt}, each providing a function called @tt{search} with the above contract.

I can write a @tech{configurable feature set definition} module that describes these different search options that looks like this:
@codeblock|{
;; configurables.rkt
#lang configurable/definition

(define-configurable search-style
  #:provides [search]

  (define-implementation literal
    #:module "search/literal.rkt")

  (define-implementation regex
    #:module "search/regex.rkt")

  (define-implementation fuzzy
    #:module "search/fuzzy.rkt"))
}|

And now I can write a config that users can edit to select a search style, looking like this:
@codeblock|{
;; config.rkt
#lang configurable/config "configurables.rkt"

;; `fuzzy` here refers to the name of the implementation in configurables.rkt
(configure-all! [search-style fuzzy])
}|

Now, my system implementation abstracts over these different styles by just using the search function in the parameter named @tt{configured:search} provided by @tt{configurables.rkt}.
That parameter will be filled with the specific search function provided by a config file, perhaps obtained as a commandline argument, which is installed during the setup phase of my program.
So the part of the system that performs the actual search looks like this:
@verbatim{
(require "configurables.rkt")

;; setup code ...
(install-config! user-config-path)

;; later on ...
(define search (configured:search))
(define matching-lines (search text-lines search-query))
;; ...
}


