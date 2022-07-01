using Random, Distributions
using OnlineSampling
using Pkg
Pkg.activate("./visu/")
using Plots
using LinearAlgebra

# Inspired from https://youtu.be/aUkBa1zMKv4
ground(x) = [1.0] - 1 / 40.0 * I(1) * x
plotx = collect(-40:0.01:40)

# Some unceratinty parameters
const measurementNoiseStdev = 0.1 * I(1);
const speedStdev = 0.2 * I(1);

# Speed of the aircraft
const speed = [0.2];
# Set starting position of aircraft
planePosX = [-25];
planePosY = [4];

@node function true_plane()
    @init x = planePosX
    x = @prev(x) + speed
    h = planePosY - ground(x)
    return x, h
end

traj = collect(@nodeiter T = 300 true_plane())
obs = [t[2][1] for t in traj]
x_pos = [t[1] for t in traj]
alt = [planePosY - t[2] for t in traj]

@node function model()
    @init x = rand(MvNormal([0.0], [15.0]))
    x = rand(MvNormal(speed + @prev(x), speedStdev))
    h = rand(MvNormal(planePosY - ground(x), measurementNoiseStdev))
    return x, h
end

@node function infer(obs)
    x, h = @nodecall model()
    @observe(h, obs)
    return x
end

N = 500
softmax(x) = exp.(x .- maximum(x)) ./ sum(exp.(x .- maximum(x)))
cloud_iter = @nodeiter particles = N infer(eachrow(obs))

function particles_prob(cloud)
    values = [c.retvalue[1] for c in cloud.particles]
    permut = sortperm(values)
    return values[permut], softmax(cloud.logweights[permut])
end

anim = @animate for (i, cloud) in enumerate(cloud_iter)
    p = plot(plotx, [t[1] for t in ground.(plotx)], label = "")
    p = scatter!(x_pos[i], planePosY, color = "green", label = "", markersize = 5)
    p = scatter!(x_pos[i], alt[i], color = "red", label = "")
    xlims!((-40, 40))
    ylims!((0.0, 6.0))
    p = plot!([x_pos[i]; x_pos[i]], [planePosY; alt[i]], lw = 2, lc = "red", legend = false)
    (v, prob) = particles_prob(cloud)
    quiver!(v, 5 .+ zero(prob), quiver = (zero(v), 100 * prob))
end #every 1

gif(anim, "./visu/linear_part_fps30.gif", fps = 30)

cloud_iter_sbp =
    @nodeiter particles = 1 algo = streaming_belief_propagation infer(eachrow(obs))

anim = @animate for (i, cloud) in enumerate(cloud_iter_sbp)
    p = plot(plotx, [t[1] for t in ground.(plotx)], label = "")
    p = scatter!(x_pos[i], planePosY, color = "green", label = "", markersize = 5)
    p = scatter!(x_pos[i], alt[i], color = "red", label = "")
    xlims!((-40, 40))
    ylims!((0.0, 6.0))
    p = plot!([x_pos[i]; x_pos[i]], [planePosY; alt[i]], lw = 2, lc = "red", legend = false)
    dist_g = dist(cloud.particles[1])
    p = plot!(x -> 5 .+ 5*pdf(Normal(dist_g.μ[1], sqrt(dist_g.Σ[1])), x))
end 

gif(anim, "./visu/linear_sbp_fps30.gif", fps = 30)
