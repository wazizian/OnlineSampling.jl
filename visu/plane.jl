using OnlineSampling
using LinearAlgebra
using PDMats
using Random, Distributions
using Pkg
Pkg.activate("./visu/")
using visu
using Plots

ground = ground_asym
speed = [0.2]

@node function true_plane()
    @init x = planePosX
    x = @prev(x) + speed
    h = planePosY .- ground.(x)
    h_r = rand(MvNormal(h, ScalMat(1, plane_measurementNoiseStdev^2)))
    return x, h_r, h
end

traj = collect(@nodeiter T = 500 true_plane())
obs = [t[2] for t in traj]
x_pos = [t[1] for t in traj]
alt = [planePosY - t[2] for t in traj]

@node function model()
    @init x = rand(MvNormal([-10.0], [15.0]))
    x = rand(MvNormal(@prev(x) + speed, ScalMat(1, 0.04)))
    h = rand(MvNormal(planePosY .- ground.(x), ScalMat(1, plane_measurementNoiseStdev^2)))
    return x, h
end

@node function infer(obs)
    x, h = @nodecall model()
    @observe(h, obs)
    return x
end

N = 500
cloud_iter = @nodeiter particles = N infer(eachrow(obs))

estimated_pos = []
squared_pos = []
anim = @animate for (i, cloud) in enumerate(cloud_iter)
    p = plot(plotx, ground.(plotx), label = "")
    p = scatter!(x_pos[i], planePosY, color = "green", label = "", markersize = 5)
    p = scatter!(x_pos[i], alt[i], color = "red", label = "")
    xlims!((plane_x_min, plane_x_max))
    ylims!((0.0, 6.0))
    p = plot!([x_pos[i]; x_pos[i]], [planePosY; alt[i]], lw = 2, lc = "red", legend = false)
    (v, prob) = particles_prob(cloud)
    append!(estimated_pos, expectation(identity, cloud))
    append!(squared_pos, expectation(x->x.^2, cloud))
    quiver!(v, 5 .+ zero(prob), quiver = (zero(v), 100 * prob))
end

gif(anim, "./visu/plots/anim_fps30.gif", fps = 30)

#p = plot((estimated_pos-[x[1] for x in x_pos]).^2)
#p = plot!(squared_pos - estimated_pos.^2)
#savefig(p, "./visu/plots/plane_estimate_pos.svg")