# OnlineSampling.jl

OnlineSampling.jl is a Julia package for online inference on reactive probabilistic models inspired by [ProbZelus](https://github.com/IBM/probzelus).
This package provides a small domain specific language to program reactive models and a semi-symbolic inference engine based on belief propagation to perform online Bayesian inference.

Probabilistic programs are used to describe models and automatically infer latent parameters from statistical observations.
OnlineSampling focuses on reactive models, i.e., streaming probabilistic models based on the synchronous model of execution.

Programs execute synchronously in lockstep on a global discrete logical clock.
Inputs and outputs are data streams, programs are stream processors.
For such models, inference is a reactive process that returns the distribution of parameters at the current time step given the observations so far.

```@contents
Pages = ["start.md", "library.md", "internals.md"]
```