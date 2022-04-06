using OnlineSampling
using PDMats
using Distributions

@node function nonlinear_model()
    @init x = rand(MvNormal(ScalMat(1, 1.0)))
    x = rand(MvNormal(atan(@prev(x)),ScalMat(1, 0.01)))
    y = rand(MvNormal(x, ScalMat(1, 0.1)))
    return x, y
end

Base.:atan(t::OnlineSampling.TrackedObservation)= atan.(t.val)

steps = 5
obs_iter = @nodeiter T = steps nonlinear_model()
obs = [OnlineSampling.value(y) for (x,y) in obs_iter]

@node function filter(obs)
    x, y = @nodecall nonlinear_model()  
    @observe(y, obs)
    return x
end

distr = @noderun particles = 10 filter(obs)
samples = rand(distr, 20) 

import Base: atan
function atan(t::OnlineSampling.LinearTracker)
    val = BP.value!(t.gm, t.id) #here I am using BP but it should depen on Ctx
    atan.(val)
end

distr = @noderun particles = 10 BP=true filter(obs)
samples = rand(distr, 20) 