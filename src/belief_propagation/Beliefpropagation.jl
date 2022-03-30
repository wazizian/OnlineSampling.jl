module Beliefpropagation

using LinearAlgebra
using Distributions
using PDMats
using LinkedLists
using Accessors
#using Chain
#
include("../cond_distr/CondDistr.jl")
using ..CondDistr

include("structs.jl")
include("primitives.jl")
include("ops.jl")

export GraphicalModel, initialize!, value!, observe!, dist!

end
