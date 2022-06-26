using OnlineSampling
using PDMats
using Distributions

const speed = 1.0
const noise = 0.5

@node function model()
    @init x = rand(MvNormal([0.0], ScalMat(1, 1000.0))) # x_0 ~ N(0, 1000)
    x = rand(MvNormal(@prev(x), ScalMat(1, speed)))     # x_t ~ N(x_{t-1}, speed)
    y = rand(MvNormal(x, ScalMat(1, noise)))            # y_t ~ N(x_t, noise)
    return x, y
end

@node function observations()
    @init t = 1
    t = @prev(t) + 1
    println("Observation at t=$t:")
    obs = parse(Float64, readline()) # get observation
    return [obs]
end

@node function hmm()
    x, y = @nodecall model() # apply model to get x, y
    obs = @nodecall observations() # get observation
    @observe(y, obs)         # assume y_t is observed with value obs_t 
    return x
end

steps = 10

cloudbp = @noderun particles = 1 algo = belief_propagation T=steps hmm() # launch the inference with 1 particles

d = dist(cloudbp.particles[1]) # distribution for the last state
println("Last estimation with bp: mean=$(mean(d)[1]), std dev=$(sqrt(cov(d))[1,1])")
