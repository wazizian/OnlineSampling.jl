using Test
using Distributions
using HypothesisTests
using Statistics
using PDMats
using LinearAlgebra
using MacroTools
using MacroTools: postwalk
using IRTools
using OnlineSampling
import OnlineSampling._reset_node_mem_struct_types
using .DelayedSampling: is_inv_sat, Marginalized, Initialized, Realized

testdir = dirname(@__FILE__)

try
    _ = exit_on_error
catch UndefVarError
    global exit_on_error
    exit_on_error = false
end

include("custom_testset.jl")

@testset TS exit_on_error = exit_on_error "OnlineSampling.jl" begin
    @testset "simple gaussian" begin
        #include(joinpath(testdir, "delayed_sampling/simple_gaussian.jl"))
    end
    @testset "tree of gaussians" begin
        #include(joinpath(testdir, "delayed_sampling/tree_gaussian.jl"))
    end
    @testset "online smc" begin
        #include(joinpath(testdir, "online_smc/simple_gaussian.jl"))
    end
    @testset "notinit" begin
        include(joinpath(testdir, "notinit.jl"))
    end
    @testset "synchronous constructs" begin
        #include(joinpath(testdir, "simple_synchronous.jl"))
    end
    @testset "observe" begin
        #include(joinpath(testdir, "observe.jl"))
    end
    @testset "node smc" begin
        include(joinpath(testdir, "smc.jl"))
    end
end
