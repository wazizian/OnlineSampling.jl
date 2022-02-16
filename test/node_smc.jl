@testset "smc counter" begin
    @node function counter()
        @init x = 0
        x = @prev(x) + 1
    end
    @node function test()
        det = @node counter()
        smc = @node particles = 100 counter()

        @test smc isa Cloud
        @test length(smc) == 100
        @test all(v -> v == det, smc)
    end

    @node T = 5 test()
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
        x, y = @node model()
        @observe(y, obs)
        return x
    end
    @node function main(obs)
        x = @node particles = 1000 hmm(obs)
    end

    obs = Vector{Float64}(1:5)
    obs = reshape(obs, (5, 1))
    @assert size(obs) == (5, 1)

    @node T = 5 main(obs)
end

@testset "comparison gaussian hmm" begin
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
        x, y = @node model()
        @observe(y, obs)
        return x
    end

    obs = Vector{Float64}(1:5)
    obs = reshape(obs, (5, 1))
    @assert size(obs) == (5, 1)

    node_cloud = @node T = 5 particles = N hmm(obs)
    node_samples = dropdims(rand(node_cloud, Nsamples); dims = 1)

    function proposal(p::MvParticle, o)
        x = rand(MvNormal(p.val, Σ))
        d = MvNormal(x, Σ)
        return MvParticle(x, logpdf(d, o))
    end
    smc_cloud = OnlineSMC.Cloud{MvParticle}(N)
    for t = 1:5
        smc_cloud = OnlineSMC.smc_step(proposal, smc_cloud, obs[t, :])
    end
    smc_samples = dropdims(rand(smc_cloud, Nsamples); dims = 1)

    test = KSampleADTest(node_samples, smc_samples)
    @test (pvalue(test) > 0.01) || @show test
end
