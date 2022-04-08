using OnlineSampling
using PDMats
using Distributions

@node function nonlinear_model()
    @init x = rand(MvNormal(ScalMat(1, 1.0)))
    x = rand(MvNormal(atan.(@prev(x)), ScalMat(1, 0.01)))
    y = rand(MvNormal(x, ScalMat(1, 0.1)))
    return x, y
end

steps = 5
obs_iter = @nodeiter T = steps nonlinear_model()
obs = [OnlineSampling.value(y) for (x, y) in obs_iter]

@node function filter(obs)
    x, y = @nodecall nonlinear_model()
    @observe(y, obs)
    return x
end

distr = @noderun particles = 10 filter(obs)
samples = rand(distr, 20)

distr = @noderun particles = 10 BP = true filter(obs)
samples = rand(distr, 20)
