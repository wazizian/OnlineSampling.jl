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
check_not_realized(::Union{BP.Realized,DS.Realized}) = false
check_not_realized(::Any) = true

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
    cloud = @noderun T = T particles = N algo=delayed_sampling f()
    samples = dropdims(rand(cloud, Nsamples); dims = 1)
    test = OneSampleADTest(samples, Normal(0.0, sqrt(T)))
    @test (pvalue(test) > 0.05) || test

    cloud = @noderun T = T particles = N algo=belief_propagation f()
    samples = dropdims(rand(cloud, Nsamples); dims = 1)
    test = OneSampleADTest(samples, Normal(0.0, sqrt(T)))
    @test (pvalue(test) > 0.05) || test
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

    ds_cloud = @noderun T = 5 particles = N algo=delayed_sampling hmm(eachrow(obs))
    ds_samples = dropdims(rand(ds_cloud, Nsamples); dims = 1)

    bp_cloud = @noderun T = 5 particles = N algo=belief_propagation hmm(eachrow(obs))
    bp_samples = dropdims(rand(bp_cloud, Nsamples); dims = 1)

    #@show (mean(ds_cloud), mean(bp_cloud))

    #@show (cov(ds_cloud), cov(bp_cloud))
    #
    test = KSampleADTest(smc_samples, ds_samples)
    @test (pvalue(test) > 0.05) || test

    test = KSampleADTest(bp_samples, ds_samples)
    @test (pvalue(test) > 0.05) || test
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

    ds_cloud = @noderun T = T particles = N algo=delayed_sampling hmm(eachrow(obs))
    ds_samples = rand(ds_cloud, Nsamples)

    bp_cloud = @noderun T = T particles = N algo=belief_propagation hmm(eachrow(obs))
    bp_samples = rand(bp_cloud, Nsamples)

    # @show (mean(smc_cloud), mean(ds_cloud))

    # @show (cov(smc_cloud), cov(ds_cloud))

    tests = [BartlettTest, UnequalCovHotellingT2Test, EqualCovHotellingT2Test]
    for test in tests
        result = test(smc_samples', ds_samples')
        @test (pvalue(result) > 0.01) || result

        result = test(ds_samples', bp_samples')
        @test (pvalue(result) > 0.05) || result
    end
end
