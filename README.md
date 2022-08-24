![tests](https://github.com/wazizian/OnlineSampling.jl/actions/workflows/test.yml/badge.svg?branch=main)[![doc](https://img.shields.io/badge/docs-dev-blue.svg)](https://wazizian.github.io/OnlineSampling.jl/dev)

# OnlineSampling

OnlineSampling.jl is a Julia package for online inference on reactive probabilistic models inspired by [ProbZelus](https://github.com/IBM/probzelus).
This package provides a small domain specific language to program reactive models and a semi-symbolic inference engine based on belief propagation to perform online Bayesian inference.

Probabilistic programs are used to describe models and automatically infer latent parameters from statistical observations.
OnlineSampling focuses on reactive models, i.e., streaming probabilistic models based on the synchronous model of execution.

Programs execute synchronously in lockstep on a global discrete logical clock.
Inputs and outputs are data streams, programs are stream processors.
For such models, inference is a reactive process that returns the distribution of parameters at the current time step given the observations so far.

The full documentation is available at [wazizian.github.io/OnlineSampling.jl/dev](https://wazizian.github.io/OnlineSampling.jl/dev).

## Overview

See the video below from JuliaCon 2022 for a quick introduction to OnlineSampling.
[![JuliaCon 2022 OnlineSampling.jl presentation](https://img.youtube.com/vi/puXsMJOc7xE/0.jpg)](https://youtu.be/puXsMJOc7xE)
## Example

The following example is a HMM where we try to estimate the position of a moving agent from noisy observations.
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

