using Random, Distributions
using OnlineSampling
using Pkg
Pkg.activate("./visu/")
using Plots
using LinearAlgebra

# example from https://youtu.be/aUkBa1zMKv4
ground(x) =
    (x >= 10) .* (
        (1 - (x - 10) / 30) .* sin(x - 10) +
        ((x - 10) / 30) .* sin(1.5 * (x - 10)) +
        0.2 .* (x - 10) .* (x <= 20) +
        2 * (x > 20)
    ) +
    (x <= -10) .* (
        (1 - (-x - 10) / 30) .* sin(-x - 10) +
        ((-x - 10) / 30) .* sin(1.5 * (-x - 10)) +
        0.2 .* (-x - 10) .* (x >= -20) +
        2 * (x < -20)
    )
#plotVectorMountains = [collect(-40:0.01:-10.01) collect(10.01:0.01:40)]
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
    h = planePosY .- ground.(x)
    return x, h
end

traj = collect(@nodeiter T = 300 true_plane())
obs = [t[2] for t in traj]
x_pos = [t[1] for t in traj]
alt = [planePosY - t[2] for t in traj]

@node function model()
    @init x = rand(MvNormal([0.0], [15.0]))
    x = rand(MvNormal(@prev(x) + speed, speedStdev^2))
    h = rand(MvNormal(planePosY .- ground.(x), measurementNoiseStdev^2))
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
    p = sortperm(values)
    return values[p], softmax(cloud.logweights[p])
end

anim = @animate for (i, cloud) in enumerate(cloud_iter)
    p = plot(plotx, ground.(plotx), label = "")
    p = scatter!(x_pos[i], planePosY, color = "green", label = "", markersize = 5)
    p = scatter!(x_pos[i], alt[i], color = "red", label = "")
    xlims!((-40, 40))
    ylims!((0.0, 6.0))
    p = plot!([x_pos[i]; x_pos[i]], [planePosY; alt[i]], lw = 2, lc = "red", legend = false)
    (v, prob) = particles_prob(cloud)
    #p = plot!(v,5 .+ 100*prob)
    quiver!(v, 5 .+ zero(prob), quiver = (zero(v), 100 * prob))
end #every 1

gif(anim, "./visu/anim_fps30.gif", fps = 30)
