# @testset "smc counter" begin
    # N = 10
    # @node function counter()
        # @init x = 0
        # x = @prev(x) + 1
    # end
    # @node function test()
        # det = @nodecall counter()
        # smc = @nodecall algo = joint_particle_filter particles = N counter()
# 
        # @init init = true
        # init = false
        # if !init
            # @test smc isa Cloud
            # @test length(smc) == N*N
            # @test all(v -> v == (det - 1, det), smc)
        # end
    # end
# 
    # @noderun T = 5 test()
# end

@testset "gaussian rw" begin
   N = 2000
   Nsamples = 500
   dim = 1
   Σ = ScalMat(dim, 1.0)
   μ = ones(dim)
   obs = [1., 2., 3., 4., 5., 6., 7.]
   obs = reshape(obs, (length(obs), 1))
   @node function model()
       @init x = rand(MvNormal(μ, Σ))
       x = rand(MvNormal(@prev(x) + μ, Σ))
       return x
   end
   @node function hmm(obs)
       x = @nodecall model()
       y = rand(MvNormal(x, Σ))
       @observe(y, obs)
       return x
    end
   @node function test(obs)
       @init t = 0
       t = @prev(t) + 1
       cloud_x = @nodecall particles = N algo = joint_particle_filter hmm(obs)
       simple_cloud = @nodecall particles = N algo = particle_filter hmm(obs)
       if t > 0
           @test length(cloud_x) == N*N
           ex = expectation(Base.splat(vcat), cloud_x)
           @show ex
           raw_samples = rand(cloud_x, Nsamples) 
           samples = mapreduce(Base.splat(vcat), (x,y) -> cat(x,y;dims=2), raw_samples)
           @test size(samples) == (2*dim, Nsamples)
           dist = MvNormal([t*μ; (t+1)*μ], [t*Σ t*Σ; t*Σ (t+1)*Σ])
           exact_samples = rand(dist, Nsamples)
           @test size(exact_samples) == (2*dim, Nsamples)
           # tests = [BartlettTest, UnequalCovHotellingT2Test, EqualCovHotellingT2Test]
           # cov = expectation(rankone ∘ Base.splat(vcat), cloud_x) - rankone(expectation(Base.splat(vcat), cloud_x))
           # @show cov
           cov_prev = expectation(Base.splat((x, y) -> x * x'), cloud_x) - expectation(first, cloud_x) * expectation(first, cloud_x)'
           # cov_curr = expectation(Base.splat((x, y) -> y * y'), cloud_x) - expectation(t -> t[2], cloud_x) * expectation(t -> t[2], cloud_x)'
           snd = p -> p[2]
           cov_curr = expectation(Base.splat((x, y) -> y * y'), cloud_x) - expectation(snd, cloud_x) * expectation(snd, cloud_x)'
           @show cov_prev
           @show cov_curr
           cov_curr_simple = expectation(x-> x * x', simple_cloud) - expectation(identity, simple_cloud) * expectation(identity, simple_cloud)'
           @show cov_curr_simple
           # @show cloud_x
           # @show simple_cloud


#            for test in tests
#                result = test(samples', exact_samples')
#                @test (pvalue(result) > 0.01) || result
#            end
       end
   end

   @noderun T = 5 test(eachrow(obs))
end
