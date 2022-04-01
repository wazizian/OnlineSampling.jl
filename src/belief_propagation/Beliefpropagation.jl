module Beliefpropagation

using LinearAlgebra
using Distributions
using PDMats
using LinkedLists
using Accessors
#using Chain

import ..SymbInterface: initialize!, value!, rand!, observe!

include("../cond_distr/CondDistr.jl")
using ..CondDistr

include("structs.jl")
include("primitives.jl")
include("ops.jl")

export initialize!, value!, observe!, rand!

end
