var documenterSearchIndex = {"docs":
[{"location":"library/#Library","page":"Library","title":"Library","text":"","category":"section"},{"location":"library/#Synchronous-Programming","page":"Library","title":"Synchronous Programming","text":"","category":"section"},{"location":"library/","page":"Library","title":"Library","text":"A stream function is introduced by the macro @node.  Inside a node, the macro @init can be used to declare a variable as a memory. Another macro @prev can then be used to access the value of a memory variable at the previous time step.","category":"page"},{"location":"library/","page":"Library","title":"Library","text":"@node\n@init\n@prev\n@nodecall\ncst","category":"page"},{"location":"library/#OnlineSampling.@node","page":"Library","title":"OnlineSampling.@node","text":"Introduced a stream function.  E.g.,\n\n@node function one()\n    return 1\nend\n\n\n\n\n\n","category":"macro"},{"location":"library/#OnlineSampling.@init","page":"Library","title":"OnlineSampling.@init","text":"Declare a variable as a memory with a default value. Can only be used inside a @node declaration.\n\n\n\n\n\n","category":"macro"},{"location":"library/#OnlineSampling.@prev","page":"Library","title":"OnlineSampling.@prev","text":"Access the value of a memory variable at the previous time step. Can only be used inside a @node declaration.\n\n\n\n\n\n","category":"macro"},{"location":"library/#OnlineSampling.@nodecall","page":"Library","title":"OnlineSampling.@nodecall","text":"Function call for stream functions.\n\nE.g., \n\n@node function one()\n    return 1\nend\n\n@node function two()\n    x = @nodecall one()\n    return x + 1\nend\n\n\n\n\n\n","category":"macro"},{"location":"library/#OnlineSampling.cst","page":"Library","title":"OnlineSampling.cst","text":"Convenience alias for Iterators.repeated\n\n\n\n\n\n","category":"function"},{"location":"library/#Probabilistic-Programming","page":"Library","title":"Probabilistic Programming","text":"","category":"section"},{"location":"library/","page":"Library","title":"Library","text":"In a probabilistic model, random variables are introduced by rand and can be conditioned on concrete value using @observe.","category":"page"},{"location":"library/","page":"Library","title":"Library","text":"@observe","category":"page"},{"location":"library/#OnlineSampling.@observe","page":"Library","title":"OnlineSampling.@observe","text":"Condition the model with the assumption that a random variable introduced by rand takes a concrete value.\n\nx = rand(Normal(0, 1))     # x_t ~ N(0, 1)\n@observe(x, 1.5)           # assume x = 0.5\n\n\n\n\n\n","category":"macro"},{"location":"library/#Runtime","page":"Library","title":"Runtime","text":"","category":"section"},{"location":"library/","page":"Library","title":"Library","text":"Stream functions – probabilistic or not – can then be executed as Julia iterators using the following macros.","category":"page"},{"location":"library/","page":"Library","title":"Library","text":"@nodeiter\n@noderun\nAlgorithms","category":"page"},{"location":"library/#OnlineSampling.@nodeiter","page":"Library","title":"OnlineSampling.@nodeiter","text":"Turn a stream function into a julia iterator. Arguments:\n\nT is the number of iterations (optional, default=nothing)\nalgo is the probabilistic runtime (optional, see Algorithms)\nparticles is the number of particles for the probabilistic runtime (optional, default=0)\nrt is the resampling threshold (optional, default=0.5)\n\nE.g., \n\nfor x in @nodeiter T = 10 f() # for 10 iterations of f\n    println(x)                # print the current value\nend\n\n\n\n\n\n","category":"macro"},{"location":"library/#OnlineSampling.@noderun","page":"Library","title":"OnlineSampling.@noderun","text":"Unfold an iterator and return its last value Arguments:\n\nT is the number of iterations (optional, default=nothing)\nalgo is the probabilistic runtime (optional, see Algorithms)\nparticles is the number of particles for the probabilistic runtime (optional, default=0)\nrt is the resampling threshold (optional, default=0.5)\n\nE.g., \n\nres = @noderun T = 10 f()\n\n\n\n\n\n","category":"macro"},{"location":"library/#OnlineSampling.Algorithms","page":"Library","title":"OnlineSampling.Algorithms","text":"Enum type to choose the inference algorithm in @noderun and @nodeiter. Can be one of:\n\nparticle_filter\ndelayed_sampling\nbelief_propagation\nstreaming_belief_propagation\n\n\n\n\n\n","category":"type"},{"location":"start/#Getting-Started","page":"Getting Started","title":"Getting Started","text":"","category":"section"},{"location":"start/","page":"Getting Started","title":"Getting Started","text":"The examples directory contains simple examples. More comprehensive tests can be found in the test directory.","category":"page"},{"location":"start/#Synchronous-Reactive-Programming","page":"Getting Started","title":"Synchronous Reactive Programming","text":"","category":"section"},{"location":"start/","page":"Getting Started","title":"Getting Started","text":"We use julia's macro system to program reactive models in a style reminiscent of synchronous dataflow programming languages.","category":"page"},{"location":"start/","page":"Getting Started","title":"Getting Started","text":"A stream function is introduced by the macro @node. Inside a node, the macro @init can be used to declare a variable as a memory. Another macro @prev can then be used to access the value of a memory variable at the previous time step.","category":"page"},{"location":"start/","page":"Getting Started","title":"Getting Started","text":"Then, the macro @nodeiter turns a node into a julia iterator which unfolds the execution of a node for a given number of steps and returns the current value at each step. Alternatively the macro @noderun simply executes the node for a given number of steps and returns the last computed value.","category":"page"},{"location":"start/","page":"Getting Started","title":"Getting Started","text":"For examples, the following function cpt implements a simple counter incremented at each step.","category":"page"},{"location":"start/","page":"Getting Started","title":"Getting Started","text":"using OnlineSampling\n\n@node function cpt() # declare a stream processor\n    @init x = 0      # initialize a memory x with value 0\n    x = @prev(x) + 1 # at each step increment x\n    return x\nend\n\nfor x in @nodeiter T = 10 cpt() # for 10 iterations of cpt\n    println(x)                  # print the current value\nend","category":"page"},{"location":"start/#Reactive-Probabilistic-Programming","page":"Getting Started","title":"Reactive Probabilistic Programming","text":"","category":"section"},{"location":"start/","page":"Getting Started","title":"Getting Started","text":"Reactive constructs @init and @prev can be mixed with probabilistic constructs to program reactive probabilistic models.","category":"page"},{"location":"start/","page":"Getting Started","title":"Getting Started","text":"Following recent probabilistic languages (e.g., Turing.jl or Pyro) in OnlineSampling, probabilistic constructs are the following:","category":"page"},{"location":"start/","page":"Getting Started","title":"Getting Started","text":"x = rand(D) introduces a random variable x with the prior distribution D.\n@observe(x, v) conditions the models assuming the random variable x takes the value v.","category":"page"},{"location":"start/","page":"Getting Started","title":"Getting Started","text":"For example, the following example is a HMM where we try to estimate the position of a moving agent from noisy observations. At each step, we assume that the current position x is normally distributed around the previous position @prev(x), and we assume that the current observation y is normally distributed around the current position.","category":"page"},{"location":"start/","page":"Getting Started","title":"Getting Started","text":"using OnlineSampling\nusing PDMats\nusing Distributions\n\nspeed = 1.0\nnoise = 0.5\n    \n@node function model()\n    @init x = rand(MvNormal([0.0], ScalMat(1, 1000.0))) # x_0 ~ N(0, 1000)\n    x = rand(MvNormal(@prev(x), ScalMat(1, speed)))     # x_t ~ N(x_{t-1}, speed)\n    y = rand(MvNormal(x, ScalMat(1, noise)))            # y_t ~ N(x_t, noise)\n    return x, y\nend\n@node function hmm(obs)\n    x, y = @nodecall model() # apply model to get x, y\n    @observe(y, obs)         # assume y_t is observed with value obs_t \n    return x\nend\n\nsteps = 10\nobs = reshape(Vector{Float64}(1:steps), (steps, 1))  # the first dim of the input must be the number of time steps\ncloud = @nodeiter particles = 1000 hmm(eachrow(obs)) # launch the inference with 1000 particles (return an iterator)\n\nfor (x, o) in zip(cloud, obs)                                  # at each step\n    samples = rand(x, 1000)                                    # sample the 1000 values from the posterior     \n    println(\"Estimated: \", mean(samples), \" Observation: \", o) # print the results\nend","category":"page"},{"location":"start/","page":"Getting Started","title":"Getting Started","text":"At each step, this program prints the estimated position and the current observation.","category":"page"},{"location":"start/#Semi-Symbolic-Algorithm","page":"Getting Started","title":"Semi-Symbolic Algorithm","text":"","category":"section"},{"location":"start/","page":"Getting Started","title":"Getting Started","text":"The inference method used by OnlineSampling is a Rao-Blackwellised particle filter, a semi-symbolic algorithm which tries to analytically compute closed-form solutions as much as possible, and falls back to a particle filter when symbolic computations fail. For Gaussian random variables with linear relations, we implemented belief propagation if the factor graph is a tree. In this case, for any root r of the tree on n vertices, we have:","category":"page"},{"location":"start/","page":"Getting Started","title":"Getting Started","text":"p(x_1x_n) = p(x_r)prod_child in n backslash r p(x_childx_parent)","category":"page"},{"location":"start/","page":"Getting Started","title":"Getting Started","text":"Belief propagation is an efficient algorithm to compute these factors.  It extends Delayed Sampling able to compute the marginals only on a single path.","category":"page"},{"location":"start/","page":"Getting Started","title":"Getting Started","text":"As a result, in the previous HMM example, belief propagation is able to recover the equation of a Kalman filter and compute the exact solution and only one particle is necessary as shown below (full example available here) ","category":"page"},{"location":"start/","page":"Getting Started","title":"Getting Started","text":"cloudbp = @noderun particles = 1 algo = belief_propagation hmm(eachrow(obs)) # launch the inference with 1 particles for all observations\nd = dist(cloudbp.particles[1])                                               # distribution for the last state\nprintln(\"Last estimation with bp: \", mean(d), \" Observation: \", last(obs))","category":"page"},{"location":"#OnlineSampling.jl","page":"Home","title":"OnlineSampling.jl","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"OnlineSampling.jl is a Julia package for online inference on reactive probabilistic models inspired by ProbZelus. This package provides a small domain specific language to program reactive models and a semi-symbolic inference engine based on belief propagation to perform online Bayesian inference.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Probabilistic programs are used to describe models and automatically infer latent parameters from statistical observations. OnlineSampling focuses on reactive models, i.e., streaming probabilistic models based on the synchronous model of execution.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Programs execute synchronously in lockstep on a global discrete logical clock. Inputs and outputs are data streams, programs are stream processors. For such models, inference is a reactive process that returns the distribution of parameters at the current time step given the observations so far.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Pages = [\"start.md\", \"library.md\", \"internals.md\"]","category":"page"},{"location":"internals/#Internals","page":"Internals","title":"Internals","text":"","category":"section"},{"location":"internals/#Synchronous-programming","page":"Internals","title":"Synchronous programming","text":"","category":"section"},{"location":"internals/","page":"Internals","title":"Internals","text":"This package relies on Julia's metaprogramming capabilities.  Under the hood, the macro @node generates three functions.","category":"page"},{"location":"internals/","page":"Internals","title":"Internals","text":"A definition,","category":"page"},{"location":"internals/","page":"Internals","title":"Internals","text":"@node function f(x::T)::R\n    ...\nend","category":"page"},{"location":"internals/","page":"Internals","title":"Internals","text":"yields:","category":"page"},{"location":"internals/","page":"Internals","title":"Internals","text":"f(state::S, isinit::Bool, x::T)::Tuple{S, R}\nf_init(x::T)::Tuple{S, R}\nf_not_init(state::S, x::T)::Tuple{S, R}","category":"page"},{"location":"internals/","page":"Internals","title":"Internals","text":"The resulting functions implement a stateful stream processor which closely mimic the Iterator interface of Julia.","category":"page"},{"location":"internals/","page":"Internals","title":"Internals","text":"the function f only dispatches to the two versions f_init and f_not_init depending on whether the argument isinit is equal to true, i.e. on whether t = 0.\ngiven the first input, f_init (the initialization function) is executed at the first step and returns the initial state and the first output.\nthen at each step, given the current state and an input, f_no_init (the transition function) computes the next state and the return value.  ","category":"page"},{"location":"internals/","page":"Internals","title":"Internals","text":"The state correspond to the memory used to store all the variables declared with @init and access via @prev.","category":"page"},{"location":"internals/","page":"Internals","title":"Internals","text":"The heavy lifting to create these functions is done by a Julia macro which acts on the Abstract Syntax Tree (AST). The transformations at this level include :","category":"page"},{"location":"internals/","page":"Internals","title":"Internals","text":"Creating the two versions of the function.\nImplementing the initialization of the state of a node at t = 0.\nAugmenting returns with the next state of the node\nFor t  0, adding the code to retrieve the previous internal state and update it.\nHandling calls to other nodes, which are indicated by @nodecall.","category":"page"},{"location":"internals/","page":"Internals","title":"Internals","text":"However, some transformations are best done at a later stage of the Julia pipeline.  One of them is the handling of calls to @prev during the initial step t = 0. At this point, for any expression e, @prev(e) is undefined and all the code which depends on this call is invalidated and thus is not executed.  To seemlessly handle the various constructs of the Julia language, the precise semantic of this operation and its implementation are done at the level of Intermediate Representation (IR) thanks to the package ÌRTools.","category":"page"},{"location":"internals/#Probabilistic-programming","page":"Internals","title":"Probabilistic programming","text":"","category":"section"},{"location":"internals/","page":"Internals","title":"Internals","text":"To add probabilistic constructs, nodes take an extra argument: a context object which describes the inference algorithm in use; and return an extra output: the current loglikelihood, potentially updated with @observe statements.","category":"page"},{"location":"internals/","page":"Internals","title":"Internals","text":"The Julia macro thus add the following transformations:","category":"page"},{"location":"internals/","page":"Internals","title":"Internals","text":"Augmenting returns with the current log-likelihood.\nCalling the SMC or symbolic algorithms when needed.\nReplacing @observe and rand operations with custom functions which update the ambient log-likelihood and modify the symbolic structure accordingly.","category":"page"},{"location":"internals/#Symbolic-inference","page":"Internals","title":"Symbolic inference","text":"","category":"section"},{"location":"internals/","page":"Internals","title":"Internals","text":"When a symbolic inference engine is used, rand add a symbolic variable to an ambient factor graph and return an object referencing this variables.  For instance, when a multivariate Gaussian is sampled, the returned object supports linear operations since the resulting random variable remains Gaussian.  However, when an unsupported operation, e.g. a non linear function such as atan, is applied to a random variable, this variable must be sampled. This automatic realization of a variable undergoing an unsupported transform is also triggered at IR level: when a function is applied to a random variable and there is no method matching the variable type, this variable is automatically sampled.","category":"page"},{"location":"internals/","page":"Internals","title":"Internals","text":"This allows random variables to be passed around in tuples, structures or as function arguments while painlessly giving up symbolic inference when it is not possible anymore.","category":"page"},{"location":"internals/#Streaming-Belief-Propagation","page":"Internals","title":"Streaming Belief Propagation","text":"","category":"section"},{"location":"internals/","page":"Internals","title":"Internals","text":"We provide a \"pointer-minimal\" implementation of belief propagation: during execution when a random variables is not referenced anymore by the program, it can be freed by the garbage collector (GC).  In other words, the symbolic factor graph does not get in the way of the GC.  This is done gracefully thanks to the Ref mechanism in Julia, which give us the flexibility of pointers while retaining the convenience of a GC.","category":"page"}]
}
