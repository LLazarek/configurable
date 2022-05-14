#lang scribble/manual

@(require scribble/core)

@;;;;;;;;;;;;;;;@
@; Boilerplate ;@
@;;;;;;;;;;;;;;;@

@(require (for-label racket configurable)
          scribble/example)

@(define configurable-eval (make-base-eval))
@examples[#:eval configurable-eval #:hidden (require racket configurable)]

@title{configurable}
@author{Lukas Lazarek}

This library implements a simple system for software configuration.
The idea is that the system implementor can create configurable features which have multiple implementations that users can select from.
Users can then create a config that selects an implementation for each configurable feature.
The system can install a config to configure the features.

This library supports that workflow with the following design.

First, the system implementor writes a @deftech{configurable feature set definition}, specifying each feature with
1. an interface of values related to the feature
2. one or more implementations, identified by module paths.
This definition is written in the @tt{#lang configurable/define} DSL.

With the configurable feature set definition in hand, the system implementor can @racket[require] it to access each feature's interface through parameters holding their currently configured values.

A @deftech{config} defines a mapping from each feature's interface to concrete values by selecting an implementation for each feature.
The system sets the current configuration values by installing a config with @racket[install-config!].
Configs are written in the @tt{#lang configurable/config} DSL.

@section{An example}

I am implementing a system that searches text by lines, and I want users to be able to select a search algorithm; perhaps I want to support literal matching, regex, and fuzzy search.
So I wrote three modules implementing the different algorithms, all sharing the same interface. For instance,
@racketblock[((listof string?) ; full text lines
	     string?           ; search query
	     . -> .
	     (listof string?)) ; matching lines
	     ]
So now I have modules @tt{search/literal.rkt}, @tt{search/regex.rkt}, and @tt{search/fuzzy.rkt}, each providing a function called @tt{search} with the above contract.

I can write a @tech{configurable feature set definition} module that describes these different search options that looks like this:
@racketblock[
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
]

Now, my system implementation can abstract over these different styles by just using the search function in the parameter named @tt{configured:search} provided by @tt{configurables.rkt}.
So the part of the system that performs the actual search looks like this:
@verbatim[
;; lots of system ...
(define search (configured:search))
(define matching-lines (search text-lines search-query))
;; more system ...
]

Then, I can write a config module to select a search style, looking like this:
@racketblock[
;; config.rkt
#lang configurable/config "configurables.rkt"

(configure-all! [search-style fuzzy])
]

Now my system can obtain a path to a config like this one, perhaps as a commandline argument, and install it during the setup phase to set the configured value in the @tt{configured:search} parameter.
So the setup code includes something like this:
@verbatim[
;; setup code ...
;; obtaining a config path somehow
(install-config! config-path)
]

