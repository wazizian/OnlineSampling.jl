module Beliefpropagation

using LinearAlgebra
using Distributions
using PDMats
using LinkedLists
using Accessors
#using Chain

import ..OnlineSampling: dist!, observe!, initialize!

#
include("../cond_distr/CondDistr.jl")
using ..CondDistr

include("structs.jl")
include("primitives.jl")
include("ops.jl")

export GraphicalModel, initialize!, value!, observe!, dist!

end
