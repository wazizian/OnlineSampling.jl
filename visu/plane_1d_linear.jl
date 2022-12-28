using Random, Distributions
using OnlineSampling
using Pkg
Pkg.activate("./visu/")
using visu
using Plots

ground(x) = 1.0 - 1 / 40.0 * x
plotx = collect(-40:0.01:40)

# Some unceratinty parameters
measurementNoiseStdev = plane_measurementNoiseStdev
speedStdev = plane_speedStdev

# Speed of the aircraft
const speed = 0.2;
# Set starting position of aircraft
planePosX = -25;
planePosY = 4;

@node function true_plane()
    @init x = planePosX
    x = @prev(x) + speed
    h = planePosY - ground.(x)
    return x, h
end

traj = collect(@nodeiter T = 300 true_plane())

obs = [t[2] for t in traj]
x_pos = [t[1] for t in traj]
alt = [planePosY - t[2] for t in traj]

@node function model()
    @init x = rand(Normal(planePosX, sqrt(1.0)))
    x = rand(Normal(@prev(x) + speed, speedStdev))
    h = rand(Normal(planePosY - ground(x), measurementNoiseStdev))
    return x, h
end

@node function infer(obs)
    x, h = @nodecall model()
    @observe(h, obs)
    return x
end

N = 500
cloud_iter = @nodeiter particles = N infer(obs)

anim = @animate for (i, cloud) in enumerate(cloud_iter)
    p = plot(plotx, ground.(plotx), label = "")
    p = scatter!([x_pos[i]], [planePosY], color = "green", label = "", markersize = 5)
    p = scatter!([x_pos[i]], [alt[i]], color = "red", label = "")
    xlims!((-40, 40))
    ylims!((0.0, 6.0))
    p = plot!(
        [[x_pos[i]]; [x_pos[i]]],
        [[planePosY]; [alt[i]]],
        lw = 2,
        lc = "red",
        legend = false,
    )
    (v, prob) = particles_prob(cloud)
    quiver!(v, 5 .+ zero(prob), quiver = (zero(v), 100 * prob))
end

gif(anim, "./visu/plots/linear_1d_fps30.gif", fps = 30)

cloud_iter_sbp = @nodeiter particles = 1 algo = streaming_belief_propagation infer(obs)

anim = @animate for (i, cloud) in enumerate(cloud_iter_sbp)
    p = plot(plotx, ground.(plotx), label = "")
    p = scatter!([x_pos[i]], [planePosY], color = "green", label = "", markersize = 5)
    p = scatter!([x_pos[i]], [alt[i]], color = "red", label = "")
    xlims!((-40, 40))
    ylims!((0.0, 6.0))
    p = plot!(
        [[x_pos[i]]; [x_pos[i]]],
        [[planePosY]; [alt[i]]],
        lw = 2,
        lc = "red",
        legend = false,
    )
    dist_g = dist(cloud.particles[1])
    p = plot!(x -> 5 .+ 2 * pdf(Normal(dist_g.μ, dist_g.σ), x))
end

gif(anim, "./visu/plots/linear_sbp_1d_fps30.gif", fps = 30)
