using OnlineSampling
using PDMats
using Distributions
using LinearAlgebra
using OnlineSampling: irpass, value

const trans1 = [5.0]
const multi = 2.0 * I(1)

x0= OnlineSampling.TrackedObservation{Vector{Float64}, Multivariate, Continuous, IsoNormal}(
    [5.1], MvNormal([10.0],ScalMat(1, 1.0) ))

fun_test(z::typeof(x0)) = z + trans1
v_sum = irpass(fun_test,x0)

@test v_sum == trans1 + value(x0)

fun_test2(z::typeof(x0)) = multi * z 
v_mult = irpass(fun_test2,x0)

@test v_mult == multi * value(x0)