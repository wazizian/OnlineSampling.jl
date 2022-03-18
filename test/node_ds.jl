# @testset "Gaussian counter" begin
#     Σ = ScalMat(1, 1.0)
#     N = 1000
#     Nsamples = 100
#     T = 2
#     @node function f()
#         @init x = rand(MvNormal([0.0], Σ))
#         x = rand(MvNormal(@prev(x), Σ))
#         return x
#     end
#     cloud = @node T = T particles = N DS = true f()
#     samples = dropdims(rand(cloud, Nsamples); dims = 1)
#     test = OneSampleADTest(samples, Normal(0.0, sqrt(T)))
#     @test (pvalue(test) > 0.05) || test
# end

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
        x, y = @node model()
        @observe(y, obs)
        return x
    end

    obs = Vector{Float64}(1:5)
    obs = reshape(obs, (5, 1))
    @assert size(obs) == (5, 1)

    smc_cloud = @node T = 5 particles = N hmm(obs)
    smc_samples = dropdims(rand(smc_cloud, Nsamples); dims = 1)

    ds_cloud = @node T = 5 particles = N DS = true hmm(obs)
    ds_samples = dropdims(rand(ds_cloud, Nsamples); dims = 1)

    # @show (mean(smc_cloud), mean(ds_cloud))

    # @show (cov(smc_cloud), cov(ds_cloud))

    test = KSampleADTest(smc_samples, ds_samples)
    @test (pvalue(test) > 0.05) || test
end
