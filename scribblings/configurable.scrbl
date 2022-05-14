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


@section[#:tag "interface"]{Process queue interface}
@defmodule[process-queue]

@defproc[(process-queue? [q any/c]) boolean?]{
The predicate recognizing process queues.
}

@defproc[(process-queue-empty? [q process-queue?]) boolean?]{
A process queue is empty if it has no actively running processes, and no waiting processes.
}

@defproc[(process-queue-enqueue [q process-queue?] [launch (-> process-info/c)] [extra-data any/c #f]) process-queue?]{
Enqueues a process on the queue.
@racket[launch] should launch the process (e.g. with @racket[process], but not necessarily) and return its information.

@racket[extra-data] provides optional extra information that may or may not be used depending on the implementation (for example, a priority value).

Returns the updated process queue.

}

@defproc[(process-queue-wait [q process-queue?]) (and/c process-queue? process-queue-empty?)]{
Blocks waiting for all of the processes in the queue to terminate, handling the @tech{process will}s of processes as they terminate.
}

@defproc[(process-queue-active-count [q process-queue?]) natural?]{
Returns the number of actively running processes at the time of call.
}

@defproc[(process-queue-waiting-count [q process-queue?]) natural?]{
Returns the number of waiting processes at the time of call.
}

@defproc[(process-queue-set-data [q process-queue?] [data any/c]) process-queue?]{
Sets the value of the data field.
}
@defproc[(process-queue-get-data [q process-queue?]) any/c]{
Gets the value of the data field.
}

@defstruct*[process-info ([data any/c] [ctl ((or/c 'status 'wait 'interrupt 'kill) . -> . any)] [will process-will/c])]{
The struct packaging together information about a running process.
}
@defthing[#:kind "contract" process-info/c contract? #:value (struct/c process-info
		 	    		   	     	     	       any/c
								       ((or/c 'status 'wait 'interrupt 'kill) . -> . any)
								       process-will/c)]{
The contract for @racket[process-info]s.
}
@defthing[#:kind "contract" process-will/c contract? #:value (process-queue? process-info? . -> . process-queue?)]{
The contract for process wills.
}



@section[#:tag "functional"]{Functional process queue}
@defmodule[process-queue]

@defproc[(make-process-queue [active-limit positive-integer?]
			     [data any/c #f]
			     [#:kill-older-than process-timeout-seconds (or/c positive-real? #f) #f])
			     (and/c process-queue? process-queue-empty?)]{
Creates an empty functional process queue.

@racket[active-limit] is the maximum number of processes that can be active at once.

@racket[process-timeout-seconds], if non-false, specifies a "best effort" limit on the real running time of each process in seconds.
Best effort here means that the timeout is not strictly enforced in terms of timing --- i.e. a process may run for longer than @racket[process-timeout-seconds].
Instead, the library checks for over-running processes periodically while performing other operations on the queue and kills any that it finds.
This is useful as a crude way to ensure that no process runs forever.
If you need precise/strict timeout enforcement, you might consider using the @tt{timeout} unix utility or other racket tools, and using @racket[process-timeout-seconds] as a fallback.
}

@section[#:tag "priority"]{Functional process priority queue}
@defmodule[process-queue/priority]

Functional process priority queues prioritize processes to run first using a sorting function, provided when creating the queue.
These queues use the third argument of @racket[process-queue-enqueue] as the priority, which defaults to 0.

@defproc[(make-process-queue [active-limit positive-integer?]
			     [data any/c #f]
			     [priority< (any/c any/c . -> . boolean?) <]
			     [#:kill-older-than process-timeout-seconds (or/c positive-real? #f) #f])
			     (and/c process-queue? process-queue-empty?)]{
Creates an empty functional process priority queue, which prioritizes processes according to @racket[priority<].

See @secref{functional} for more details on the remaining arguments.
}

@section[#:tag "imperative"]{Imperative process queue}
@defmodule[process-queue/imperative]

The imperative process queue implementation mutates a single process queue in-place instead of functionally transforming it.
Hence, all of the @secref{interface} operations that return a new process queue simply return the input queue after mutating it.

@defproc[(make-process-queue [active-limit positive-integer?]
			     [data any/c #f]
			     [#:kill-older-than process-timeout-seconds (or/c positive-real? #f) #f])
			     (and/c process-queue? process-queue-empty?)]{
Creates an empty imperative process priority queue.

See @secref{functional} for more details on the remaining arguments.
}

