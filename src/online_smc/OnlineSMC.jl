module OnlineSMC
import Distributions
using StatsFuns: softmax, logsumexp
using AdvancedPS: ResampleWithESSThreshold, resample_systematic
using Random
using LinearAlgebra
using Chain
using Accessors

include("cloud.jl")
include("smc.jl")

export Cloud, expectation
end
