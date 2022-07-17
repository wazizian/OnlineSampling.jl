module CondDistr

using LinearAlgebra
using Distributions
using PDMats
using Accessors
using Chain

include("cd.jl")
include("linear_gaussian_cd.jl")
include("beta_cd.jl")

export condition,
    CdMvNormal,
    CdNormal,
    CdBernoulli,
    CdBinomial,
    ConditionalDistribution,
    DummyCD,
    condition_cd,
    jointdist

end
