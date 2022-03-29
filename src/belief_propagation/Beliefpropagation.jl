module Beliefpropagation

using LinearAlgebra
using Distributions
using PDMats
using LinkedLists
using Accessors
#using Chain


include("linear_gaussian_cd.jl")
include("structs.jl")
include("primitives.jl")
include("ops.jl")

export GraphicalModel, initialize!, value!, observe!, dist!, CdMvNormal

end