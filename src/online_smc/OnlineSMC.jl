module OnlineSMC
import Distributions
using AdvancedPS: ResampleWithESSThreshold
using Random
using LinearAlgebra
using Chain

include("cloud.jl")
include("smc.jl")

export Cloud, expectation, smc_step
end
