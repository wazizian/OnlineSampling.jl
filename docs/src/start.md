# Getting Started

The `examples` directory contains simple examples.
More comprehensive tests can be found in the `test` directory.

## Synchronous Reactive Programming

We use julia's macro system to program reactive models in a style reminiscent of synchronous dataflow programming languages.

A stream function is introduced by the macro [`@node`](@ref).
Inside a `node`, the macro [`@init`](@ref) can be used to declare a variable as a memory.
Another macro [`@prev`](@ref) can then be used to access the value of a memory variable at the previous time step.

Then, the macro [`@nodeiter`](@ref) turns a node into a julia iterator which unfolds the execution of a node for a given number of steps and returns the current value at each step.
Alternatively the macro [`@noderun`](@ref) simply executes the node for a given number of steps and returns the last computed value.

For examples, the following function `cpt` implements a simple counter incremented at each step.

```@example
using OnlineSampling

@node function cpt() # declare a stream processor
    @init x = 0      # initialize a memory x with value 0
    x = @prev(x) + 1 # at each step increment x
    return x
end

for x in @nodeiter T = 10 cpt() # for 10 iterations of cpt
    println(x)                  # print the current value
end
```

## Reactive Probabilistic Programming

Reactive constructs `@init` and `@prev` can be mixed with probabilistic constructs to program reactive probabilistic models.

Following recent probabilistic languages (e.g., [Turing.jl](https://turing.ml/) or [Pyro](https://pyro.ai/)) in OnlineSampling, probabilistic constructs are the following:
- `x = rand(D)` introduces a random variable `x` with the prior distribution `D`.
- `@observe(x, v)` conditions the models assuming the random variable `x` takes the value `v`.

For example, the following example is a HMM where we try to estimate the position of a moving agent from noisy observations.
At each step, we assume that the current position `x` is normally distributed around the previous position `@prev(x)`, and we assume that the current observation `y` is normally distributed around the current position.

```@example hmm
using OnlineSampling
using PDMats
using Distributions

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

steps = 10
obs = reshape(Vector{Float64}(1:steps), (steps, 1))  # the first dim of the input must be the number of time steps
cloud = @nodeiter particles = 1000 hmm(eachrow(obs)) # launch the inference with 1000 particles (return an iterator)

for (x, o) in zip(cloud, obs)                                  # at each step
    samples = rand(x, 1000)                                    # sample the 1000 values from the posterior     
    println("Estimated: ", mean(samples), " Observation: ", o) # print the results
end
```

At each step, this program prints the estimated position and the current observation.

## Semi-symbolic algorithm

The inference method used by OnlineSampling is a Rao-Blackwellised particle filter, a semi-symbolic algorithm which tries to analytically compute closed-form solutions as much as possible, and falls back to a particle filter when symbolic computations fail.
For Gaussian random variables with linear relations, we implemented [belief propagation](https://en.wikipedia.org/wiki/Belief_propagation) if the factor graph is a tree. In this case, for any root $r$ of the tree on $n$ vertices, we have $p(x_1,...x_n) = p(x_r)\prod_{child \in [n] \backslash r} p(x_{child}|x_{parent})$ and belief propagation is an efficient algorithm to compute these factors. 
It extends [Delayed Sampling](https://arxiv.org/abs/1708.07787) able to compute the marginals only on a single path.

As a result, in the previous HMM example, belief propagation is able to recover the equation of a Kalman filter and compute the exact solution and only one particle is necessary as shown below (full example available [here](https://github.com/wazizian/OnlineSampling.jl/blob/main/examples/hmm.jl)) 

```@example hmm
cloudbp = @noderun particles = 1 algo = belief_propagation hmm(eachrow(obs)) # launch the inference with 1 particles for all observations
d = dist(cloudbp.particles[1])                                               # distribution for the last state
println("Last estimation with bp: ", mean(d), " Observation: ", last(obs))
```