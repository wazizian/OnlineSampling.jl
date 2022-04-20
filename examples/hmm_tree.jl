using OnlineSampling
using PDMats
using Distributions
using LinearAlgebra
using OnlineSampling: value

const speed_tree = 10.0
const trans1 = [5.0]
const trans_noise = 5.0
const noise = 0.5
const mult = reshape([2.0],1,1)

@node function model()
    @init x0 = rand(MvNormal([0.0], ScalMat(1, 1000.0))) 
    x0 = rand(MvNormal(@prev(x0), ScalMat(1, speed)))
    x1 = rand(MvNormal(x0 + trans1 , ScalMat(1, trans_noise)))
    x2 = rand(MvNormal(mult * x0, ScalMat(1, trans_noise)))
    y1 = rand(MvNormal(x1, ScalMat(1, noise)))
    y2 = rand(MvNormal(x2, ScalMat(1, noise)))            
    return x0, x1, x2, y1, y2
end

steps = 2
trajectory = @nodeiter T = steps model()
obs_y1 = [value(t[end-1]) for t in trajectory]
obs_y2 = [value(t[end]) for t in trajectory]

@node function hmm(obs1, obs2)
    x0,x1,x2, y1,y2 = @nodecall model() 
    @observe(y1, obs1)         
    @observe(y2, obs2) 
    return x0, x1, x2
end

cloud = @noderun particles = 1 hmm(obs_y1,obs_y2)
#cloudds = @noderun particles = 1 algo = delayed_sampling hmm(eachrow(obs),eachrow(obs)) #not working
cloudbp = @noderun particles = 1 algo = belief_propagation hmm(obs_y1, obs_y2)
dbp = dist(cloudbp.particles[1])
cloudsbp = @noderun particles = 1 algo = streaming_belief_propagation hmm(obs_y1, obs_y2)
dsbp = dist(cloudsbp.particles[1])

@assert [mean(d) for d in dbp] == [mean(d) for d in dsbp]
@assert [var(d) for d in dbp] == [var(d) for d in dsbp]
