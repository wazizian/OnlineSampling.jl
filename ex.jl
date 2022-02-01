using OnlineSampling

clear() = (_ = Base.run(`clear`))
reload() = (OnlineSampling._reset_node_mem_struct_types(); clear(); include("ex.jl"))

@node function counter()
    @init x = 0
    x = @prev(x) + 1
    @show x
end
# @node T = 10 counter()

@node function incr(x)
    return x + 1
end
@node function intricate_counter()
    @init x = 0
    x = @node incr(@prev(y))
    y = x
    @show x
end
# @node T = 10 intricate_counter()


function side_effect(arr, a, b)
    push!(arr, a)
    return b
end

function side_effect_int(arr, a, b::Integer)
    push!(arr, a)
    return b
end

@node function pathological_prev(arr)
    @init x = 0
    @init y = 0
    y = @prev x
    x = side_effect_int(arr, y, (@prev y) + 1)
    @show x
end
arr = []
# @node T = 5 f(arr)
# arr == [0, 0, 1, 1, 2] 








@node function ret_counter()
    @init x = 0
    x = @prev(x) + 1
    return x
end
@node function test()
    det = @node ret_counter()
    smc = @node particles = 100 ret_counter()

    @assert smc isa Cloud
    @assert length(smc) == 100
    @assert all(v -> v == det, smc)
end

# @node T = 5 test()


using LinearAlgebra, PDMats
using PDMats: ScalMat

Σ = ScalMat(1, 1.0)
@node function model()
    @init x = rand(MvNormal([0.0], Σ))
    x = rand(MvNormal(@prev(x), Σ))
    y = rand(MvNormal(x, Σ))
    return x, y
end
@node function hmm(obs)
    x, y = @node model()
    @observe(y, obs)
    return x
end
@node function main(obs)
    x = @node particles = 1000 hmm(obs)
end

obs = Vector{Float64}(1:5)
# @test_broken (@node T=5 main(obs))
