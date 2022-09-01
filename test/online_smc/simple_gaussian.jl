const N = 10000
const Nsamples = 1000
const atol = 5 / sqrt(min(N, Nsamples))
const rtol = 0.05
const resample_threshold = 0.5

@testset "tools" begin
    d = MvNormal([0.0], ScalMat(1, 1.0))
    xs = rand(d, N)
    @assert size(xs) == (1, N)

    cloud = OnlineSMC.Cloud([MvParticle(x, 0.0) for x in eachcol(xs)])
    @test mean(cloud) ≈ mean(d) atol = atol
    @test cov(cloud) ≈ cov(d) atol = atol

    samples = dropdims(rand(cloud, Nsamples); dims = 1)
    @test mean(samples) ≈ only(mean(d)) atol = atol
    @test var(samples) ≈ only(cov(d)) atol = atol

    test = OneSampleADTest(samples, Normal(only(mean(d)), only(cov(d))))
    @test_skip (pvalue(test) > 0.05) || @show test
end

@testset "observe child" begin
    function proposal!(p::MvParticle)
        val = rand(MvNormal([0.0], ScalMat(1, 1.0)))
        y = rand(MvNormal(3 .* val .+ 1, ScalMat(1, 2.0)))
        obs_y = 2.0
        loglikelihood = -0.25 * (3 * only(val) + 1 - only(obs_y))^2
        return MvParticle(val, loglikelihood)
    end

    cloud = OnlineSMC.Cloud{MvParticle}(N)
    new_cloud = OnlineSMC.smc_step(proposal!, resample_threshold, cloud)

    target = MvNormal([3 / 11], ScalMat(1, 2 / 11))
    @test mean(new_cloud) ≈ mean(target) rtol = rtol
    @test cov(new_cloud) ≈ cov(target) rtol = rtol

    samples = dropdims(rand(new_cloud, Nsamples); dims = 1)
    @test mean(samples) ≈ only(mean(target)) atol = atol
    @test var(samples) ≈ only(cov(target)) atol = atol

    test =
        OneSampleADTest(samples, Normal((only ∘ mean)(target), (sqrt ∘ only ∘ cov)(target)))
    @test (pvalue(test) > 0.05) || @show test
end

@randtestset "iterate gaussians" begin
    # Model
    # X_1 ∼ N(0, 1)
    # X_{t+1} ∼ N(X_t, 1)
    # observe Y_T ∼ N(X_T, 1)
    function proposal!(p::MvParticle)
        val = rand(MvNormal(p.val, ScalMat(1, 1.0)))
        return MvParticle(val, 0.0)
    end

    T = 10
    cloud = OnlineSMC.Cloud{MvParticle}(N)
    for _ = 1:(T-1)
        cloud = OnlineSMC.smc_step(proposal!, resample_threshold, cloud)
    end
    obs_y = [1.0]
    cloud = OnlineSMC.smc_step(resample_threshold, cloud) do p
        new_p = proposal!(p)
        loglikelihood = -0.5 * (only(obs_y) - (only ∘ OnlineSMC.value)(new_p))^2
        return MvParticle(OnlineSMC.value(new_p), loglikelihood)
    end

    σ = sqrt(T / (T + 1))
    target = MvNormal(σ^2 * obs_y, ScalMat(1, σ^2))
    @test mean(cloud) ≈ mean(target) rtol = rtol
    @test cov(cloud) ≈ cov(target) rtol = rtol

    samples = dropdims(rand(cloud, Nsamples); dims = 1)
    @test mean(samples) ≈ only(mean(target)) atol = atol
    @test var(samples) ≈ only(cov(target)) atol = atol

    test =
        OneSampleADTest(samples, Normal((only ∘ mean)(target), (sqrt ∘ only ∘ cov)(target)))
    @test (pvalue(test) > 0.05) || @show test
end
