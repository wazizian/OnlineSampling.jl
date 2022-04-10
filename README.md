![tests](https://github.com/wazizian/OnlineSampling.jl/actions/workflows/test.yml/badge.svg?branch=main)

# OnlineSampling

OnlineSampling.jl is a Julia package for online Bayesian inference on reactive probabilistic models.
This package provides a small domain specific language to program reactive models and a semi-symbolic inference engine based on Delayed Sampling for online Bayesian inference.

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
@node function cpt()   # declare a stream processor
    @init x = 0        # initialize a memory x with value 0
    x = @prev(x) + 1   # at each step increment x
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


Under the hood, the macro `@node` generate two functions:
- an allocation function that allocate the memory used to store all the variables declared with `@init`
- a transition function which, at each step, 1) compute the next value for all the variable, and 2) update the memory for the next step.


## Reactive Probabilistic Programming

Reactive constructs `@init` and `@pre` can be mixed with probabilistic constructs to program reactive probabilistic models.

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
    x, y = @nodecall model()  # apply model to get x, y
    @observe(y, obs)          # assume y_t is observed with value obs_t 
    return x
end

steps = 100
obs = reshape(Vector{Float64}(1:steps), (steps, 1))  # the first dim of the input must be the number of time steps
cloud = @nodeiter particles = 1000 hmm(eachrow(obs))    # launch the inference with 1000 particles (return an iterator)

for (x, o) in zip(cloud, obs)                                      # at each step
    samples = rand(x, 1000)                                       # sample the 1000 values from the posterior     
    println("Estimated: ", mean(samples), " Observation: ", o)    # print the results
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
For Gaussian random variables with linear relations, we implemented [belief propagation](https://en.wikipedia.org/wiki/Belief_propagation) if the factor graph is a tree. In this case, for any root $r$ of the tree on $n$ vertices, we have $p(x_1,...x_n) = p(x_r)\prod_{child \in [n] \backslash r} p(x_{child}|x_{parent})$ and belief propagation is an efficient algorithm computing these factors as required. It extends [Delayed Sampling](https://arxiv.org/abs/1708.07787) able to compute the marginals only on a single path.

As a result, in the previous HMM example, belief propagation is able to recover the equation of a Kalman filter and compute the exact solution and only one particle is necessary.

