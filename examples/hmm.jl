using OnlineSampling
using PDMats
using Distributions

speed = 1.0
noise = 0.5

@node function model()
    @init x = rand(MvNormal([0.0], ScalMat(1, 1000.0))) # x_0 ~ N(0, 1000)
    x = rand(MvNormal(@prev(x), ScalMat(1, speed)))     # x_t ~ N(x_{t-1}, speed)
    y = rand(MvNormal(x, ScalMat(1, noise)))            # y_t ~ N(x_t, noise)
    return x, y
end
@node function hmm(obs)
    x, y = @nodecall model() # apply model to get x, y
    @observe(y, obs)         # assume y_t is observed with value obs_t 
    return x
end

steps = 100
obs = reshape(Vector{Float64}(1:steps), (steps, 1)) # the first dim of the input must be the number of time steps
cloud = @nodeiter particles = 1000 hmm(eachrow(obs)) # launch the inference with 1000 particles (return an iterator)

for (x, o) in zip(cloud, obs)                                  # at each step
    samples = rand(x, 1000)                                    # sample the 1000 values from the posterior     
    println("Estimated: ", mean(samples), " Observation: ", o) # print the results
end

cloudbp = @noderun particles = 1 algo = belief_propagation hmm(eachrow(obs)) # launch the inference with 1 particles for all observations

d = dist(cloudbp.particles[1]) # distribution for the last state
println("Last estimation with bp: ", mean(d), " Observation: ", last(obs))
