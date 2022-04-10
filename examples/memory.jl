using OnlineSampling
using PDMats
using Distributions
using LinearAlgebra

#################################
############ WIP ###############
#################################

function print_memory(pid)
    return run(`ps -o vsz= $pid`)
end

function main()
    N = 5000
    Nsamples = 1000
    dim = 10
    ϵ = 1
    T = 80

    function gensdp()
        m = randn(dim, dim)
        return normalize(m' * m + ϵ * I, 2)
    end

    A, C = gensdp(), gensdp()
    Σ = gensdp() |> PDMat
    b, d = randn(dim), randn(dim)

    @node function model()
        @init x = rand(MvNormal(zeros(dim), Σ))
        μx = A * @prev(x) + b
        x = rand(MvNormal(μx, Σ))
        @assert size(x) == (dim,)

        μy = C * x + d
        @assert size(x) == (dim,)

        y = rand(MvNormal(μy, Σ))
        @assert size(x) == (dim,)

        return x, y
    end
    @node function hmm(obs)
        x, y = @nodecall model()
        @observe(y, obs)
        return x
    end

    obs = randn(T, dim)
    @assert size(obs) == (T, dim)

    @node function main_node(pid, algo, obs)
        @init t = 1
        t = @prev(t) + 1
        print("[t = $t] ")
        print_memory(pid)
        return @nodecall particles = N algo = algo hmm(obs)
    end

    pid = getpid()

    algorithms = instances(OnlineSampling.Algorithms)

    for algo in algorithms
        @show algo
        @noderun T = T main_node(cst(pid), cst(algo), eachrow(obs))
    end
end

main()
