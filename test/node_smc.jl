const resample_threshold = 0.5

@testset "smc counter" begin
    @node function counter()
        @init x = 0
        x = @prev(x) + 1
    end
    @node function test()
        det = @nodecall counter()
        smc = @nodecall particles = 100 counter()

        @test smc isa Cloud
        @test length(smc) == 100
        @test all(v -> v == det, smc)
    end

    @noderun T = 5 test()
end

@testset "gaussian hmm" begin
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
        return x
    end
    @node function main(obs)
        x = @nodecall particles = 1000 hmm(obs)
    end

    obs = Vector{Float64}(1:5)
    obs = reshape(obs, (5, 1))
    @assert size(obs) == (5, 1)

    @noderun T = 5 main(eachrow(obs))
end

@randtestset "comparison gaussian hmm" begin
    N = 10000
    Nsamples = 1000

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
        return x
    end

    obs = Vector{Float64}(1:5)
    obs = reshape(obs, (5, 1))
    @assert size(obs) == (5, 1)

    node_cloud = @noderun T = 5 particles = N hmm(eachrow(obs))
    node_samples = dropdims(rand(node_cloud, Nsamples); dims = 1)

    function proposal(p::MvParticle, o)
        x = rand(MvNormal(p.val, Σ))
        d = MvNormal(x, Σ)
        return MvParticle(x, logpdf(d, o))
    end
    smc_cloud = OnlineSMC.Cloud{MvParticle}(N)
    for t = 1:5
        smc_cloud = OnlineSMC.smc_step(proposal, resample_threshold, smc_cloud, obs[t, :])
    end
    smc_samples = dropdims(rand(smc_cloud, Nsamples); dims = 1)

    test = KSampleADTest(node_samples, smc_samples)
    @test (pvalue(test) > 0.05) || @show test
end

@randtestset "comparison scalar gaussian hmm" begin
    N = 10000
    Nsamples = 1000
    drift_x = 1.0
    drift_y = -1.0

    Σ = ScalMat(1, 4.0)
    @node function model()
        @init x = rand(MvNormal([0.0], Σ))
        x = rand(MvNormal(@prev(x) + [drift_x], Σ))
        y = rand(MvNormal(x + [drift_y], Σ))
        return x, y
    end
    @node function hmm(obs)
        x, y = @nodecall model()
        @observe(y, obs)
        return x
    end

    σ = 2.0
    @node function model1d()
        @init x = rand(Normal(0.0, σ))
        x = rand(Normal(@prev(x) + drift_x, σ))
        y = rand(Normal(x + drift_y, σ))
        return x, y
    end
    @node function hmm1d(obs)
        x, y = @nodecall model1d()
        @observe(y, obs)
        return x
    end
    obs = Vector{Float64}(1:5)
    obs = reshape(obs, (5, 1))
    @assert size(obs) == (5, 1)

    node_cloud = @noderun T = 5 particles = N hmm(eachrow(obs))
    node_samples = dropdims(rand(node_cloud, Nsamples); dims = 1)

    obs = reshape(obs, (5,))
    @assert size(obs) == (5,)

    node_cloud1d = @noderun T = 5 particles = N hmm1d(obs)
    node_samples1d = vec(rand(node_cloud1d, Nsamples))

    test = KSampleADTest(node_samples, node_samples1d)
    @test (pvalue(test) > 0.05) || @show test
end
