![tests](https://github.com/wazizian/OnlineSampling.jl/actions/workflows/test.yml/badge.svg?branch=main)

# OnlineSampling

OnlineSampling.jl is a Julia package for online inference on reactive probabilistic models.
This package provides a small domain specific language to program reactive models and a semi-symbolic inference engine based on belief propagation to perform online Bayesian inference.

Probabilistic programs are used to describe models and automatically infer latent parameters from statistical observations.
OnlineSampling focuses on reactive models, i.e., streaming probabilistic models based on the synchronous model of execution.

Programs execute synchronously in lockstep on a global discrete logical clock.
Inputs and outputs are data streams, programs are stream processors.
For such models, inference is a reactive process that returns the distribution of parameters at the current time step given the observations so far.

## Install

Using the Julia package manager from source.

```
] add "."
```

You can launch the test suite with the following command.

```
] test OnlineSampling
```

## Getting Started

The `examples` directory contains simple examples.
More comprehensive tests can be found in the `test` directory.

## Synchronous Reactive Programming

We use julia's macro system to program reactive models in a style reminiscent of synchronous dataflow programming languages.

A stream function is introduced by the macro `@node`.
Inside a `node`, the macro `@init` can be used to declare a variable as a memory.
Another macro `@prev` can then be used to access the value of a memory variable at the previous time step.

Then, the macro `@nodeiter` turns a node into a julia iterator which unfolds the execution of a node for a given number of steps and returns the current value at each step.
Alternatively the macro `@noderun` simply executes the node for a given number of steps and returns the last computed value.

For examples, the following function `cpt` implements a simple counter incremented at each step.

```julia
@node function cpt() # declare a stream processor
    @init x = 0      # initialize a memory x with value 0
    x = @prev(x) + 1 # at each step increment x
    return x
end

for x in @nodeiter T = 10 cpt() # for 10 iterations of cpt
    println(x)                  # print the current value
end
```

You can run this example in the julia toplevel

```
> include("examples/counter.jl")
0
1
2
3
4
5
6
7
8
9
```

Or directly from the terminal.

```
$ julia --project=. examples/counter.jl
```

## Reactive Probabilistic Programming

Reactive constructs `@init` and `@prev` can be mixed with probabilistic constructs to program reactive probabilistic models.

Following recent probabilistic languages (e.g., [Turing.jl](https://turing.ml/) or [Pyro](https://pyro.ai/)) in OnlineSampling, probabilistic constructs are the following:
- `x = rand(D)` introduces a random variable `x` with the prior distribution `D`.
- `@observe(x, v)` conditions the models assuming the random variable `x` takes the value `v`.

For example, the following example is a HMM where we try to estimate the position of a moving agent from noisy observations.
At each step, we assume that the current position `x` is normally distributed around the previous position `@prev(x)`, and we assume that the current observation `y` is normally distributed around the current position.

```julia
speed = 1.0
noise = 0.5
    
@node function model()
    @init x = rand(MvNormal([0.0], ScalMat(1, 1000.0))) # x_0 ~ N(0, 1000)
    x = rand(MvNormal(@prev(x), ScalMat(1, speed)))     # x_t ~ N(x_{t-1}, speed)
    y = rand(MvNormal(x, ScalMat(1, noise)))            # y_t ~ N(x_t, noise)
    return x, y
end
@node function hmm(obs)
    x, y = @nodecall model() # apply model to get x, y
    @observe(y, obs)         # assume y_t is observed with value obs_t 
    return x
end

steps = 100
obs = reshape(Vector{Float64}(1:steps), (steps, 1))  # the first dim of the input must be the number of time steps
cloud = @nodeiter particles = 1000 hmm(eachrow(obs)) # launch the inference with 1000 particles (return an iterator)

for (x, o) in zip(cloud, obs)                                  # at each step
    samples = rand(x, 1000)                                    # sample the 1000 values from the posterior     
    println("Estimated: ", mean(samples), " Observation: ", o) # print the results
end
```

At each step, this program prints the estimated position and the current observation.

```
$ julia --project=. examples/hmm.jl
Estimated: 1.0347103786435585 Observation: 1.0
Estimated: 1.7946457499669912 Observation: 2.0
Estimated: 2.760280175950971 Observation: 3.0
Estimated: 3.673951109330031 Observation: 4.0
...
```

## Semi-symbolic algorithm

The inference method used by OnlineSampling is a Rao-Blackwellised particle filter, a semi-symbolic algorithm which tries to analytically compute closed-form solutions as much as possible, and falls back to a particle filter when symbolic computations fail.
For Gaussian random variables with linear relations, we implemented [belief propagation](https://en.wikipedia.org/wiki/Belief_propagation) if the factor graph is a tree. In this case, for any root $r$ of the tree on $n$ vertices, we have $p(x_1,...x_n) = p(x_r)\prod_{child \in [n] \backslash r} p(x_{child}|x_{parent})$ and belief propagation is an efficient algorithm to compute these factors. 
It extends [Delayed Sampling](https://arxiv.org/abs/1708.07787) able to compute the marginals only on a single path.

As a result, in the previous HMM example, belief propagation is able to recover the equation of a Kalman filter and compute the exact solution and only one particle is necessary as shown below (full example available [here](https://github.com/wazizian/OnlineSampling.jl/blob/main/examples/hmm.jl)) 

```julia
cloud = @noderun particles = 1 algo = belief_propagation hmm(eachrow(obs)) # launch the inference with 1 particles for all observations
d = dist(cloud.particles[1])                                               # distribution for the last state
println("Estimated: ", mean(d), " Observation: ", last(obs))
```

## Internals

### Synchronous programming

This package relies on Julia's metaprogramming capabilities. 
Under the hood, the macro `@node` generates three functions.

A definition,
```
@node function f(x::T)::R
    ...
end
```
yields:

```
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

### Probabilistic programming

To add probabilistic constructs, nodes take an extra argument: a context object which describes the inference algorithm in use; and return an extra output: the current loglikelihood, potentially updated with `@observe` statements.

The Julia macro thus add the following transformations:
- Augmenting returns with the current log-likelihood.
- Calling the SMC or symbolic algorithms when needed.
- Replacing `@observe` and `rand` operations with custom functions which update the ambient log-likelihood and modify the symbolic structure accordingly.


### Symbolic inference

When a symbolic inference engine is used, `rand` add a symbolic variable to an ambient factor graph and return an object referencing this variables. 
For instance, when a multivariate Gaussian is sampled, the returned object supports linear operations since the resulting random variable remains Gaussian. 
However, when an unsupported operation, e.g. a non linear function such as `atan`, is applied to a random variable, this variable must be sampled.
This automatic realization of a variable undergoing an unsupported transform is also triggered at IR level: when a function is applied to a random variable and there is no method matching the variable type, this variable is automatically sampled.

This allows random variables to be passed around in tuples, structures or as function arguments while painlessly giving up symbolic inference when it is not possible anymore.

### Streaming Belief Propagation

We provide a "pointer-minimal" implementation of belief propagation: during execution when a random variables is not referenced anymore by the program, it can be freed by the garbage collector (GC). 
In other words, the symbolic factor graph does not get in the way of the GC. 
This is done gracefully thanks to the `Ref` mechanism in Julia, which give us the flexibility of pointers while retaining the convenience of a GC.








