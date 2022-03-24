using OnlineSampling
using PDMats
using Distributions

function main()
    speed = 1.0
    noise = 0.5

    @node function model()
        @init x = rand(MvNormal([0.0], ScalMat(1, speed)))
        x = rand(MvNormal(@prev(x), ScalMat(1, speed)))
        y = rand(MvNormal(x, ScalMat(1, noise)))
        return x, y
    end
    @node function hmm(obs)
        x, y = @node model()
        @observe(y, obs)
        return x
    end

    steps = 100
    obs = reshape(Vector{Float64}(1:steps), (steps, 1))
    dist = @node T = steps particles = 1000 hmm(obs)
    samples = rand(dist, 1000)
    println("Last position: ", mean(samples), " expected: ", obs[steps])
end

main()
