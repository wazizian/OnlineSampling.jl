"""
    Test function
"""
check_not_realized(lt::OnlineSampling.AbstractTrackedRV) =
    check_not_realized(OnlineSampling.SymbInterface.get_node(lt.gm, lt.id))
check_not_realized(::Union{BP.Realized,DS.Realized,SBP.Realized}) = false
check_not_realized(::Any) = true

"""
    Test function
"""
check_symb(::OnlineSampling.AbstractTrackedRV) = true
check_symb(::Any) = false

"""
    Test function
"""
check_symb_not_realized(x) = check_symb(x) && check_not_realized(x)

symb_algorithms = (delayed_sampling, belief_propagation, streaming_belief_propagation)

@testset "Gaussian random walk" begin
    Σ = ScalMat(1, 1.0)
    N = 1000
    Nsamples = 100
    T = 2
    @node function f()
        @init x = rand(MvNormal([0.0], Σ))
        x = rand(MvNormal(@prev(x), Σ))
        check_symb(x)
        return x
    end
    for algo in symb_algorithms
        cloud = @noderun T = T particles = N algo = algo f()
        samples = dropdims(rand(cloud, Nsamples); dims = 1)
        test = OneSampleADTest(samples, Normal(0.0, sqrt(T)))
        @test_skip (pvalue(test) > 0.05) || @show (algo, test)
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
    @node function hmm(issymb, obs)
        x, y = @nodecall model()
        @observe(y, obs)
        @assert check_not_realized(x)
        issymb && @assert check_symb(x)
        return x
    end

    obs = Vector{Float64}(1:5)
    obs = reshape(obs, (5, 1))
    @assert size(obs) == (5, 1)

    smc_cloud = @noderun T = 5 particles = N hmm(cst(false), eachrow(obs))
    smc_samples = dropdims(rand(smc_cloud, Nsamples); dims = 1)

    symb_clouds = [
        (@noderun T = 5 particles = N algo = algo hmm(cst(true), eachrow(obs))) for
        algo in symb_algorithms
    ]
    symb_samples =
        [dropdims(rand(symb_cloud, Nsamples); dims = 1) for symb_cloud in symb_clouds]

    test = KSampleADTest(smc_samples, first(symb_samples))
    @test (pvalue(test) > 0.05) || @show test

    for (algo, symb_sample) in Iterators.drop(zip(symb_algorithms, symb_samples), 1)
        test = KSampleADTest(first(symb_samples), symb_sample)
        @test_skip (pvalue(test) > 0.05) || @show (algo, test)
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
    @node function hmm(issymb, obs)
        x, y = @nodecall model()
        @observe(y, obs)
        @assert check_not_realized(x)
        issymb && @assert check_symb(x)
        return x
    end

    obs = randn(T, dim)
    @assert size(obs) == (T, dim)

    smc_cloud = @noderun T = T particles = N hmm(cst(false), eachrow(obs))
    smc_samples = rand(smc_cloud, Nsamples)

    symb_clouds = [
        (@noderun T = T particles = N algo = algo hmm(cst(true), eachrow(obs))) for
        algo in symb_algorithms
    ]
    symb_samples = [rand(symb_cloud, Nsamples) for symb_cloud in symb_clouds]

    tests = [BartlettTest, UnequalCovHotellingT2Test, EqualCovHotellingT2Test]
    for test in tests
        result = test(smc_samples', first(symb_samples)')
        @test_skip (pvalue(result) > 0.01) || result
    end

    for (algo, symb_sample) in Iterators.drop(zip(symb_algorithms, symb_samples), 1)
        for test in tests
            result = test(first(symb_samples)', symb_sample')
            @test_skip (pvalue(result) > 0.05) || @show (algo, result)
        end
    end
end

@testset "coin flip" begin
    N = 1000
    T = 1000

    @node function model()
        @init p = rand(Beta(10, 10))
        p = @prev(p)
        coin = rand(Bernoulli(p))
        return p, coin
    end

    @node function infer(issymb, obs)
        p, coin = @nodecall model()
        issymb && @assert check_symb_not_realized(coin)

        @observe(coin, obs)
        issymb && @assert check_symb_not_realized(p)

        return p
    end

    iter = @nodeiter T = T model()
    rets = collect(iter)
    p_true = rets[1][1]
    obs = [ret[2] for ret in rets]
    @assert size(obs) == (T,)

    smc_cloud = @noderun T = T particles = N infer(cst(false), obs)

    @test mean(smc_cloud) ≈ p_true atol = 0.05

    symb_clouds = [
        (@noderun T = T particles = 1 algo = algo infer(cst(true), obs)) for
        algo in symb_algorithms
    ]
    for (algo, cloud) in zip(symb_algorithms, symb_clouds)
        @test mean(cloud) ≈ p_true atol = 0.05
    end
end

@testset "Binomial samples" begin
    n = 100
    T = 1000
    @node function model()
        @init p = rand(Beta(10, 10))
        p = @prev(p)
        disc_rv = rand(Binomial(n, p))
        return p, disc_rv
    end

    iter = @nodeiter T = T model()
    rets = collect(iter)
    p_true = rets[1][1]
    obs = [ret[2] for ret in rets]

    @node function infer(obs)
        p, disc_rv = @nodecall model()
        @observe(disc_rv, obs)
        return p
    end

    symb_clouds =
        [(@noderun T = T particles = 1 algo = algo infer(obs)) for algo in symb_algorithms]
    for (algo, cloud) in zip(symb_algorithms, symb_clouds)
        @test mean(cloud) ≈ p_true atol = 0.05
    end
end
