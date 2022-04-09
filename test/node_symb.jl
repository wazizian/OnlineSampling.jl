"""
    Debug function: to print the actual distribution of a
    linear tracker
"""
dist(lt::OnlineSampling.LinearTracker) = OnlineSampling.SymbInterface.dist(lt.gm, lt.id)
dist(x::OnlineSampling.AbstractTrackedObservation) = x

"""
    Test function
"""
check_not_realized(lt::OnlineSampling.LinearTracker) =
    check_not_realized(lt.gm.nodes[lt.id])
check_not_realized(::Union{BP.Realized,DS.Realized,SBP.Realized}) = false
check_not_realized(::Any) = true

symb_algorithms = (delayed_sampling, belief_propagation, streaming_belief_propagation)

@testset "Gaussian random walk" begin
    Σ = ScalMat(1, 1.0)
    N = 1000
    Nsamples = 100
    T = 2
    @node function f()
        @init x = rand(MvNormal([0.0], Σ))
        x = rand(MvNormal(@prev(x), Σ))
        return x
    end
    for algo in symb_algorithms
        cloud = @noderun T = T particles = N algo=algo f()
        samples = dropdims(rand(cloud, Nsamples); dims = 1)
        test = OneSampleADTest(samples, Normal(0.0, sqrt(T)))
        @test (pvalue(test) > 0.05) || @show (algo, test)
    end
end

@testset "Comparison 1D gaussian hmm" begin
    N = 1000
    Nsamples = 100
    Σ = ScalMat(1, 1.0)

    @node function model()
        @init x = rand(MvNormal([0.0], Σ))
        x = rand(MvNormal(@prev(x), Σ))
        y = rand(MvNormal(x, Σ))
        return x, y
    end
    @node function hmm(obs)
        x, y = @nodecall model()
        @observe(y, obs)
        @assert check_not_realized(x)
        return x
    end

    obs = Vector{Float64}(1:5)
    obs = reshape(obs, (5, 1))
    @assert size(obs) == (5, 1)

    smc_cloud = @noderun T = 5 particles = N hmm(eachrow(obs))
    smc_samples = dropdims(rand(smc_cloud, Nsamples); dims = 1)

    symb_clouds = [(@noderun T = 5 particles = N algo=algo hmm(eachrow(obs))) for algo in symb_algorithms]
    symb_samples = [dropdims(rand(symb_cloud, Nsamples); dims = 1) for symb_cloud in symb_clouds]

    test = KSampleADTest(smc_samples, first(symb_samples))
    @test (pvalue(test) > 0.05) || @show test

    for (algo, symb_sample) in Iterators.drop(zip(symb_algorithms, symb_samples), 1)
        test = KSampleADTest(first(symb_samples), symb_sample)
        @test (pvalue(test) > 0.05) || @show (algo, test)
    end
end

@testset "Comparison d-dim gaussian hmm" begin
    N = 5000
    Nsamples = 1000
    dim = 2
    ϵ = 1
    T = 5

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
        @assert check_not_realized(x)
        return x
    end

    obs = randn(T, dim)
    @assert size(obs) == (T, dim)

    smc_cloud = @noderun T = T particles = N hmm(eachrow(obs))
    smc_samples = rand(smc_cloud, Nsamples)

    symb_clouds = [(@noderun T = T particles = N algo=algo hmm(eachrow(obs))) for algo in symb_algorithms]
    symb_samples = [rand(symb_cloud, Nsamples) for symb_cloud in symb_clouds]

    tests = [BartlettTest, UnequalCovHotellingT2Test, EqualCovHotellingT2Test]
    for test in tests
        result = test(smc_samples', first(symb_samples)')
        @test (pvalue(result) > 0.01) || result
    end

    for (algo, symb_sample) in Iterators.drop(zip(symb_algorithms, symb_samples), 1)
        for test in tests
            result = test(first(symb_samples)', symb_sample')
            @test (pvalue(result) > 0.05) || @show (algo, result)
        end
    end
end
