# Library

## Synchronous Programming

A stream function is introduced by the macro [`@node`](@ref). 
Inside a node, the macro [`@init`](@ref) can be used to declare a variable as a memory.
Another macro [`@prev`](@ref) can then be used to access the value of a memory variable at the previous time step.

```@docs
@node
@init
@prev
@nodecall
cst
```

## Probabilistic Programming

In a probabilistic model, random variables are introduced by `rand` and can be conditioned on concrete value using [`@observe`](@ref).

```@docs
@observe
```

## Runtime

Stream functions -- probabilistic or not -- can then be executed as Julia iterators using the following macros.

```@docs
@nodeiter
@noderun
Algorithms
```