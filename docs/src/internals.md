# Internals

## Synchronous programming

This package relies on Julia's metaprogramming capabilities. 
Under the hood, the macro `@node` generates three functions.

A definition,
```julia
@node function f(x::T)::R
    ...
end
```
yields:

```julia
f(state::S, isinit::Bool, x::T)::Tuple{S, R}
f_init(x::T)::Tuple{S, R}
f_not_init(state::S, x::T)::Tuple{S, R}
```

The resulting functions implement a stateful stream processor which closely mimic the `Iterator` interface of Julia.

- the function `f` only dispatches to the two versions `f_init` and `f_not_init` depending on whether the argument `isinit` is equal to true, i.e. on whether $t = 0$.
- given the first input, `f_init` (the initialization function) is executed at the first step and returns the initial state and the first output.
- then at each step, given the current state and an input, `f_no_init` (the transition function) computes the next state and the return value.  

The state correspond to the memory used to store all the variables declared with `@init` and access via `@prev`.


The heavy lifting to create these functions is done by a Julia macro which acts on the Abstract Syntax Tree (AST). The transformations at this level include :
- Creating the two versions of the function.
- Implementing the initialization of the state of a node at $t = 0$.
- Augmenting returns with the next state of the node
- For $t > 0$, adding the code to retrieve the previous internal state and update it.
- Handling calls to other nodes, which are indicated by `@nodecall`.

However, some transformations are best done at a later stage of the Julia pipeline. 
One of them is the handling of calls to `@prev` during the initial step $t = 0$.
At this point, for any expression `e`, `@prev(e)` is undefined and all the code which depends on this call is invalidated and thus is not executed. 
To seemlessly handle the various constructs of the Julia language, the precise semantic of this operation and its implementation are done at the level of Intermediate Representation (IR) thanks to the package `ÌRTools`.

## Probabilistic programming

To add probabilistic constructs, nodes take an extra argument: a context object which describes the inference algorithm in use; and return an extra output: the current loglikelihood, potentially updated with `@observe` statements.

The Julia macro thus add the following transformations:
- Augmenting returns with the current log-likelihood.
- Calling the SMC or symbolic algorithms when needed.
- Replacing `@observe` and `rand` operations with custom functions which update the ambient log-likelihood and modify the symbolic structure accordingly.


## Symbolic inference

When a symbolic inference engine is used, `rand` add a symbolic variable to an ambient factor graph and return an object referencing this variables. 
For instance, when a multivariate Gaussian is sampled, the returned object supports linear operations since the resulting random variable remains Gaussian. 
However, when an unsupported operation, e.g. a non linear function such as `atan`, is applied to a random variable, this variable must be sampled.
This automatic realization of a variable undergoing an unsupported transform is also triggered at IR level: when a function is applied to a random variable and there is no method matching the variable type, this variable is automatically sampled.

This allows random variables to be passed around in tuples, structures or as function arguments while painlessly giving up symbolic inference when it is not possible anymore.

## Streaming Belief Propagation

We provide a "pointer-minimal" implementation of belief propagation: during execution when a random variables is not referenced anymore by the program, it can be freed by the garbage collector (GC). 
In other words, the symbolic factor graph does not get in the way of the GC. 
This is done gracefully thanks to the `Ref` mechanism in Julia, which give us the flexibility of pointers while retaining the convenience of a GC.



