using Random, Distributions
using OnlineSampling
using Pkg
Pkg.activate("./visu/")
using visu
using Plots

ground = ground_sym
plotx = collect(-40:0.01:40)

# Some unceratinty parameters
const measurementNoiseStdev = 0.1;
const speedStdev = 0.2;

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
    @init x = rand(Normal(0.0, 15.0))
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
cloud_iter = @nodeiter particles = N infer(eachrow(obs))


function particles_prob(cloud)
    values = [c.retvalue[1] for c in cloud.particles]
    p = sortperm(values)
    return values[p], softmax(cloud.logweights[p])
end


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
    #p = plot!(v,5 .+ 100*prob)
    quiver!(v, 5 .+ zero(prob), quiver = (zero(v), 100 * prob))
end #every 1

gif(anim, "./visu/plots/anim_1d_fps30.gif", fps = 30)
