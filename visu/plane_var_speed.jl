include("basics_plane.jl")

ground = ground_asym

# Average speed of the aircraft
M_speed = [0.1];
var_speed = 0.3
@node function true_plane()
    @init x = planePosX
    @init time = 0
    time = @prev(time) + 1
    speed_plane = M_speed .+ var_speed*sin(time/30.)
    x = @prev(x) + speed_plane
    h = planePosY .- ground.(x)
    h_r = rand(MvNormal(h,ScalMat(1, measurementNoiseStdev^2)))
    return x, h, h_r, speed_plane
end

traj = collect(@nodeiter T = 820 true_plane())
current_speed = [t[end] for t in traj]
obs = [t[3] for t in traj]
x_pos = [t[1] for t in traj]
alt = [planePosY - t[3] for t in traj]

#plot([x[1] for x in x_pos],[s[1] for s in current_speed])

anim = @animate for (i,t) in enumerate(traj)
    p = plot(plotx, ground.(plotx), label = "")
    p = scatter!(x_pos[i], planePosY, color = "green", label = "", markersize = 5)
    p = scatter!(x_pos[i], alt[i], color = "red", label = "")
    xlims!((x_min, x_max))
    ylims!((0.0, 6.0))
    p = plot!([x_pos[i]; x_pos[i]], [planePosY; alt[i]], lw = 2, lc = "red", legend = false)
    p = plot!([x[1] for x in x_pos],[4+s[1] for s in current_speed], label = "")
end

gif(anim, "./visu/var_speed_fps30.gif", fps = 30)

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

N = 500 

cloud_iter = @nodeiter particles = N infer(obs)

function eval_speed(cloud)
    speeds = [mean(dist(c)[2]) for c in cloud.particles]
    return mean(speeds)
end

all_s =[]
anim = @animate for (i,cloud) in enumerate(cloud_iter)
    p = plot(plotx, ground.(plotx), label = "")
    p = scatter!(x_pos[i], planePosY, color = "green", label = "", markersize = 5)
    p = scatter!(x_pos[i], alt[i], color = "red", label = "")
    xlims!((x_min, x_max))
    ylims!((0.0, 6.0))
    p = plot!([x_pos[i]; x_pos[i]], [planePosY; alt[i]], lw = 2, lc = "red", legend = false)
    p = plot!([x[1] for x in x_pos],[4+s[1] for s in current_speed], label = "")
    e_s = eval_speed(cloud)
    append!(all_s, 4+e_s)
    p = plot!([x[1] for x in x_pos[1:i]], all_s, color = "blue", label = "")
    (v, prob) = particles_prob(cloud)
    quiver!(v, 5 .+ zero(prob), quiver = (zero(v), 100 * prob))
end

gif(anim, "./visu/var_speed_part_fps30.gif", fps = 30)

cloud_iter_sbp = @nodeiter particles = N algo = streaming_belief_propagation infer(obs)
all_s =[]
anim= @animate for (i,cloud) in enumerate(cloud_iter_sbp)
    p = plot(plotx, ground.(plotx), label = "")
    p = scatter!(x_pos[i], planePosY, color = "green", label = "", markersize = 5)
    p = scatter!(x_pos[i], alt[i], color = "red", label = "")
    xlims!((x_min, x_max))
    ylims!((0.0, 6.0))
    p = plot!([x_pos[i]; x_pos[i]], [planePosY; alt[i]], lw = 2, lc = "red", legend = false)
    p = plot!([x[1] for x in x_pos],[4+s[1] for s in current_speed], label = "")
    e_s = eval_speed(cloud)
    append!(all_s, 4+e_s[1])
    p = plot!([x[1] for x in x_pos[1:i]], all_s, color = "blue", label = "")
    (v, prob) = particles_prob(cloud)
    quiver!(v, 5 .+ zero(prob), quiver = (zero(v), 100 * prob))
end

gif(anim, "./visu/var_speed_sbp_fps30.gif", fps = 30)

@node function simple_model()
    @init x = rand(MvNormal([-10.0], [15.0]))
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
anim = @animate for (i,cloud) in enumerate(cloud_simple_iter)
    p = plot(plotx, ground.(plotx), label = "")
    p = scatter!(x_pos[i], planePosY, color = "green", label = "", markersize = 5)
    p = scatter!(x_pos[i], alt[i], color = "red", label = "")
    xlims!((x_min, x_max))
    ylims!((0.0, 6.0))
    p = plot!([x_pos[i]; x_pos[i]], [planePosY; alt[i]], lw = 2, lc = "red", legend = false)
    p = plot!([x[1] for x in x_pos],[4+s[1] for s in current_speed], label = "")
    (v, prob) = particles_prob(cloud)
    quiver!(v, 5 .+ zero(prob), quiver = (zero(v), 100 * prob))
end

gif(anim, "./visu/var_speed_simple_fps30.gif", fps = 30)