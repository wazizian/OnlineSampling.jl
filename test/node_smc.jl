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
