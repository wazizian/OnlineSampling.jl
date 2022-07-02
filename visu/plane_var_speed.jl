using OnlineSampling
using PDMats
using Distributions
using LinearAlgebra
using Pkg
Pkg.activate("./visu/")
using Plots

# example from https://youtu.be/aUkBa1zMKv4
ground(x) =
    (x >= 10) .* (
        (1 - (x - 10) / 30) .* sin(x - 10) +
        ((x - 10) / 30) .* sin(1.5 * (x - 10)) +
        0.2 .* (x - 10) .* (x <= 20) +
        (2+ 0.05 .*(x-20)) * (x > 20) 
    ) +
    (x <= -10) .* (
        (1 - (-x - 10) / 30) .* sin(-x - 10) +
        ((-x - 10) / 30) .* sin(1.5 * (-x - 10)) +
        0.2 .* (-x - 10) .* (x >= -20) +
        2 * (x < -20)
    )
#plotVectorMountains = [collect(-40:0.01:-10.01) collect(10.01:0.01:40)]
plotx = collect(-40:0.01:40)
p = plot(plotx, ground.(plotx), label = "")
# Some unceratinty parameters
measurementNoiseStdev = 0.1;
speedStdev = 0.25;

# Speed of the aircraft
M_speed = [0.1];
# Set starting position of aircraft
planePosX = [-35];
planePosY = [4];

#const M = speed * I(1)

@node function true_plane()
    @init x = planePosX
    @init time = 0
    time = @prev(time) + 1
    speed_plane = M_speed .+ speedStdev*sin(time/10.)
    x = @prev(x) + speed_plane
    h = planePosY .- ground.(x)
    return x, h, speed_plane
end

@node function random_plane()
    @init x = planePosX
    @init speed_plane = M_speed
    #time = @prev(time) + 1
    speed_plane = rand(MvNormal(@prev(speed_plane), ScalMat(1, 0.0005)))
    x = @prev(x) + speed_plane
    h = planePosY .- ground.(x)
    return x, h, speed_plane
end


traj = collect(@nodeiter T = 750 true_plane())
current_speed = [t[3] for t in traj]
obs = [t[2] for t in traj]
x_pos = [t[1] for t in traj]
alt = [planePosY - t[2] for t in traj]

plot([x[1] for x in x_pos],[s[1] for s in current_speed])

@gif for (i,t) in enumerate(traj)
    p = plot(plotx, ground.(plotx), label = "")
    p = scatter!(x_pos[i], planePosY, color = "green", label = "", markersize = 5)
    p = scatter!(x_pos[i], alt[i], color = "red", label = "")
    xlims!((-40, 40))
    ylims!((0.0, 6.0))
    p = plot!([x_pos[i]; x_pos[i]], [planePosY; alt[i]], lw = 2, lc = "red", legend = false)
    p = plot!([x[1] for x in x_pos],[4+s[1] for s in current_speed], label = "")
end every 1

@node function model()
    @init x = rand(MvNormal([-10.0], ScalMat(1, 15.0)))
    @init speed = rand(MvNormal(M_speed, ScalMat(1, 0.02)))
    x = rand(MvNormal(@prev(x) + @prev(speed), ScalMat(1, 0.25)))
    speed = rand(MvNormal(@prev(speed), ScalMat(1, 0.01)))
    h = rand(MvNormal(planePosY - ground.(x), ScalMat(1, measurementNoiseStdev^2)))
    return x, h, speed
end

@node function infer(obs)
    x, h, speed = @nodecall model()
    @observe(h, obs)
    return x, speed
end

N = 700 
softmax(x) = exp.(x .- maximum(x)) ./ sum(exp.(x .- maximum(x)))

cloud_iter = @nodeiter particles = N infer(obs)
#cloud = first(cloud_iter)
function particles_prob(cloud)
    values = [c.retvalue[1][1] for c in cloud.particles]
    permut = sortperm(values)
    return values[permut], softmax(cloud.logweights[permut])
end

function eval_speed(cloud)
    speeds = [mean(dist(c)[2]) for c in cloud.particles]
    return mean(speeds)
end

all_s =[]
@gif for (i,cloud) in enumerate(cloud_iter)
    p = plot(plotx, ground.(plotx), label = "")
    p = scatter!(x_pos[i], planePosY, color = "green", label = "", markersize = 5)
    p = scatter!(x_pos[i], alt[i], color = "red", label = "")
    xlims!((-40, 40))
    ylims!((0.0, 6.0))
    p = plot!([x_pos[i]; x_pos[i]], [planePosY; alt[i]], lw = 2, lc = "red", legend = false)
    p = plot!([x[1] for x in x_pos],[4+s[1] for s in current_speed], label = "")
    e_s = eval_speed(cloud)
    append!(all_s, 4+e_s)
    p = plot!([x[1] for x in x_pos[1:i]], all_s, color = "blue", label = "")
    (v, prob) = particles_prob(cloud)
    quiver!(v, 5 .+ zero(prob), quiver = (zero(v), 100 * prob))
end every 1

cloud_iter_sbp = @nodeiter particles = N algo = streaming_belief_propagation infer(obs)
all_s =[]
@gif for (i,cloud) in enumerate(cloud_iter_sbp)
    p = plot(plotx, ground.(plotx), label = "")
    p = scatter!(x_pos[i], planePosY, color = "green", label = "", markersize = 5)
    p = scatter!(x_pos[i], alt[i], color = "red", label = "")
    xlims!((-40, 40))
    ylims!((0.0, 6.0))
    p = plot!([x_pos[i]; x_pos[i]], [planePosY; alt[i]], lw = 2, lc = "red", legend = false)
    p = plot!([x[1] for x in x_pos],[4+s[1] for s in current_speed], label = "")
    e_s = eval_speed(cloud)
    append!(all_s, 4+e_s[1])
    p = plot!([x[1] for x in x_pos[1:i]], all_s, color = "blue", label = "")
    (v, prob) = particles_prob(cloud)
    quiver!(v, 5 .+ zero(prob), quiver = (zero(v), 100 * prob))
end every 1

@node function simple_model()
    @init x = rand(MvNormal([-20.0], [15.0]))
    x = rand(MvNormal(@prev(x) + M_speed, 0.25))
    h = rand(MvNormal(planePosY .- ground.(x), measurementNoiseStdev))
    return x, h
end

@node function simple_infer(obs)
    x, h = @nodecall simple_model()
    @observe(h, obs)
    return x
end

cloud_simple_iter = @nodeiter particles = N simple_infer(eachrow(obs))

all_s =[]
@gif for (i,cloud) in enumerate(cloud_simple_iter)
    p = plot(plotx, ground.(plotx), label = "")
    p = scatter!(x_pos[i], planePosY, color = "green", label = "", markersize = 5)
    p = scatter!(x_pos[i], alt[i], color = "red", label = "")
    xlims!((-40, 40))
    ylims!((0.0, 6.0))
    p = plot!([x_pos[i]; x_pos[i]], [planePosY; alt[i]], lw = 2, lc = "red", legend = false)
    p = plot!([x[1] for x in x_pos],[4+s[1] for s in current_speed], label = "")
    #e_s = eval_speed(cloud)
    #append!(all_s, 4+e_s[1])
    #p = plot!([x[1] for x in x_pos[1:i]], all_s, color = "blue", label = "")
    (v, prob) = particles_prob(cloud)
    quiver!(v, 5 .+ zero(prob), quiver = (zero(v), 100 * prob))
end every 1