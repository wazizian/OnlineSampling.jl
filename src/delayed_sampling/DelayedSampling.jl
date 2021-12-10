module DelayedSampling

using LinearAlgebra
using Distributions
using PDMats
using LinkedLists
using Accessors
using Chain

include("cd.jl")
include("structs.jl")
include("linear_gaussian_cd.jl")
include("primitives.jl")
include("ops.jl")

export  
    GraphicalModel,
    initialize!,
    value!,
    observe!,
    dist!,
    jointdist!,
    CdMvNormal

end
