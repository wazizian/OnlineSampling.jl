using Test
using Distributions
using HypothesisTests
using PDMats
using LinearAlgebra
using OnlineSampling
using .DelayedSampling: is_inv_sat, Marginalized, Initialized, Realized

testdir = dirname(@__FILE__)

try
    _ = exit_on_error
catch UndefVarError
    global exit_on_error
    exit_on_error = false
end

include("custom_testset.jl")

@testset TS exit_on_error=exit_on_error "OnlineSampling.jl" begin
    @testset "simple gaussian" begin
        include(joinpath(testdir, "simple_gaussian.jl"))
    end
    @testset "tree of gaussians" begin
        include(joinpath(testdir, "tree_gaussian.jl"))
    end
end
