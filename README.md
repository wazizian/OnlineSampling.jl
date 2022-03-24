# OnlineSampling

OnlineSampling.jl is a Julia package for online Bayesian inference on reactive probabilistic models.
This package provides a small DSL to program reactive models and a semi-symbolic inference engine based on Delayed Sampling for online Bayesian inference.

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

For examples, the following function `cpt` implements a simple counter incremented at each step.

```julia
@node function cpt()
    @init x = 0
    x = @prev(x) + 1
    println(x)
end

@node T = 10 cpt()
```

The last line `@node T = 10 cpt()` runs `cpt` for 10 steps.

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


Under the hood, the macro `@node` generate two functions:
- an allocation function that allocate the memory used to store all the variables declared with `@init`
- a transition function which, at each step, 1) compute the next value for all the variable, and 2) update the memory for the next step.


## Reactive Probabilistic Programming

Reactive constructs `@init` and `@pre` can be mixed with probabilistic constructs to program reactive probabilistic models.

In OnlineSampling, probabilistic constructs are the following:
- `x = rand(D)` introduces a random variable `x` with the prior distribution `D`.
- `@observe(x, v)` conditions the models assuming the random variable `x` takes the value `v`.

For example, the following example is a HMM where we try to estimate the position of a moving agent from noisy observations.
At each step, we assume that the current position `x` is normally distributed around the previous position `@prev(x)`, and we assume that the current observation `y` is normally distributed around the current position.

```julia
speed = 1.0
noise = 0.5
    
@node function model()
    @init x = rand(MvNormal([0.0], ScalMat(1, speed)))
    x = rand(MvNormal(@prev(x), ScalMat(1, speed)))
    y = rand(MvNormal(x, ScalMat(1, noise)))
    return x, y
end
@node function hmm(obs)
    x, y = @node model()
    @observe(y, obs)
    return x
end

steps = 100
obs = reshape(Vector{Float64}(1:steps), (steps, 1))
dist = @node T = steps particles = 1000 hmm(obs)
samples = rand(dist, 1000)
println("Last position: ", mean(samples), " expected: ", obs[steps])
```

This program print the last estimated position after 100 steps, where at time $i$, the observation is `i`.

```
$ julia --project=. examples/hmm.jl
Last position: 99.65353886804048 expected: 100.0
```