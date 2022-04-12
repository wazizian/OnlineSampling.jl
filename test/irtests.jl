using OnlineSampling
using PDMats
using Distributions
using LinearAlgebra
using OnlineSampling: irpass, value

trans1 = [5.0]
mult = 2.0 * I(1)
x0= OnlineSampling.TrackedObservation{Vector{Float64}, Multivariate, Continuous, IsoNormal}(
    [5.1], MvNormal([10.0],ScalMat(1, 1.0) ))

# This test is working thanks to overloading done in observe.jl
fun_test(z::typeof(x0)) = z + trans1
v_sum = irpass(fun_test,x0)

@test v_sum == trans1 + value(x0)

# For some reason, this test does not need overloading
fun_test2(z::typeof(x0)) = mult * z 
v_mult = irpass(fun_test2,x0)

@test v_mult == mult * value(x0)