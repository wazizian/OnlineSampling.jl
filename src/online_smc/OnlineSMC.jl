module OnlineSMC
import Distributions
using StatsFuns: softmax
using AdvancedPS: ResampleWithESSThreshold, resample_systematic
using Random
using LinearAlgebra
using Chain

include("cloud.jl")
include("smc.jl")

export Cloud, expectation
end
