include("basics_plane.jl")
include("utmb.jl")

ground = ground_utmb
M_speed = [20]
var_speed = 5.0
plotx = plotx_utmb

@node function true_trail()
    @init x = startPosX
    @init speed = M_speed
    speed = rand(MvNormal(@prev(speed), ScalMat(1, var_speed)))
    x = @prev(x) + speed
    h = ground.(x)
    h_r = rand(MvNormal(h, ScalMat(1, measurementNoiseStdev^2)))
    return x, h_r, h, speed
end

traj = collect(@nodeiter T = 800 true_trail())
obs = [t[2] for t in traj]
x_pos = [t[1] for t in traj]
alt = [t[3] for t in traj]
current_speed = [t[end] for t in traj]

plot([x_pos_utmb(x[1]) for x in x_pos], [o[1] for o in obs])
plot!(plotx, ground.(plotx), label = "")
plot([(x[1]) for x in x_pos], [s[1] for s in current_speed], label = "")

plot([(x[1]) for x in x_pos], [o[1] for o in obs] .- [ground(x[1]) for x in x_pos])

@gif for (i, t) in enumerate(traj)
    p = plot(plotx, ground.(plotx), label = "")
    p = scatter!(x_pos_utmb.(x_pos[i]), obs[i], color = "green", label = "", markersize = 5)
    p = scatter!(x_pos_utmb.(x_pos[i]), 0, color = "red", label = "")
    #xlims!((x_min, x_max))
    ylims!((0.0, y_max))
    p = plot!(
        [x_pos_utmb.(x_pos[i]); x_pos_utmb.(x_pos[i])],
        [alt[i]; 0],
        lw = 2,
        lc = "red",
        legend = false,
    )
    p = plot!(
        [x_pos_utmb(x[1]) for x in x_pos],
        [2 + s[1] / 40 for s in current_speed],
        label = "",
    )
end

#gif(anim, "./visu/trail_speed_fps30.gif", fps = 30)

@node function model()
    @init x = rand(MvNormal([0], [100.0]))
    x = rand(MvNormal(@prev(x), ScalMat(1, 1000)))
    h = rand(MvNormal(ground.(x), ScalMat(1, measurementNoiseStdev^2)))
    return x, h
end

@node function infer(obs)
    x, h = @nodecall model()
    @observe(h, obs)
    return x
end

N = 50
cloud_iter = @nodeiter particles = N infer(obs)

#estimated_pos = []
#squared_pos = []
@gif for (i, cloud) in enumerate(cloud_iter)
    p = plot(plotx, ground.(plotx), label = "")
    p = scatter!(x_pos_utmb.(x_pos[i]), alt[i], color = "green", label = "", markersize = 5)
    p = scatter!(x_pos_utmb.(x_pos[i]), 0, color = "red", label = "")
    #xlims!((x_min, x_max))
    ylims!((0.0, y_max))
    p = plot!(
        [x_pos_utmb.(x_pos[i]); x_pos_utmb.(x_pos[i])],
        [alt[i]; 0],
        lw = 2,
        lc = "red",
        legend = false,
    )
    (v, prob) = particles_prob(cloud)
    #append!(estimated_pos, expectation(identity, cloud))
    #append!(squared_pos, expectation(x->x.^2, cloud))
    quiver!(x_pos_utmb.(v), 2 .+ zero(prob), quiver = (zero(v), prob))
end


#plot((estimated_pos-[x[1] for x in x_pos]).^2)
#plot!(squared_pos - estimated_pos.^2)

#N = 50
@node function infer_true(obs)
    x, h, _, speed = @nodecall true_trail()
    @observe(h, obs)
    return x, speed
end

cloud_true_iter = @nodeiter particles = N infer_true(obs)

@gif for (i, cloud) in enumerate(cloud_true_iter)
    p = plot(plotx, ground.(plotx), label = "")
    p = scatter!(x_pos_utmb.(x_pos[i]), alt[i], color = "green", label = "", markersize = 5)
    p = scatter!(x_pos_utmb.(x_pos[i]), 0, color = "red", label = "")
    #xlims!((x_min, x_max))
    ylims!((0.0, y_max))
    p = plot!(
        [x_pos_utmb.(x_pos[i]); x_pos_utmb.(x_pos[i])],
        [alt[i]; 0],
        lw = 2,
        lc = "red",
        legend = false,
    )
    (v, prob) = particles_prob(cloud)
    #append!(estimated_pos, expectation(identity, cloud))
    #append!(squared_pos, expectation(x->x.^2, cloud))
    quiver!(x_pos_utmb.(v), 2 .+ zero(prob), quiver = (zero(v), prob))
end



@node function model_speed()
    @init x = startPosX  #rand(MvNormal([0.0], ScalMat(1, 100.0)))
    @init speed = M_speed#rand(MvNormal(M_speed, ScalMat(1, 5.0)))
    x = rand(MvNormal(@prev(x) + @prev(speed), ScalMat(1, 100.0)))
    speed = rand(MvNormal(@prev(speed), ScalMat(1, 5.0)))
    h = rand(MvNormal(ground.(x), ScalMat(1, measurementNoiseStdev^2)))
    return x, h, speed
end

@node function infer_speed(obs)
    x, h, speed = @nodecall model_speed()
    @observe(h, obs)
    return x, speed
end

cloud_speed_iter = @nodeiter particles = N infer_speed(obs)

@gif for (i, cloud) in enumerate(cloud_speed_iter)
    p = plot(plotx, ground.(plotx), label = "")
    p = scatter!(x_pos_utmb.(x_pos[i]), alt[i], color = "green", label = "", markersize = 5)
    p = scatter!(x_pos_utmb.(x_pos[i]), 0, color = "red", label = "")
    #xlims!((x_min, x_max))
    ylims!((0.0, y_max))
    p = plot!(
        [x_pos_utmb.(x_pos[i]); x_pos_utmb.(x_pos[i])],
        [alt[i]; 0],
        lw = 2,
        lc = "red",
        legend = false,
    )
    (v, prob) = particles_prob(cloud)
    #append!(estimated_pos, expectation(identity, cloud))
    #append!(squared_pos, expectation(x->x.^2, cloud))
    quiver!(x_pos_utmb.(v), 2 .+ zero(prob), quiver = (zero(v), prob))
end

cloud_speedsbp_iter =
    @nodeiter particles = N algo = streaming_belief_propagation infer_speed(obs)
#cloud = collect(Iterators.take(cloud_speedsbp_iter,4))

@gif for (i, cloud) in enumerate(cloud_speedsbp_iter)
    p = plot(plotx, ground.(plotx), label = "")
    p = scatter!(x_pos_utmb.(x_pos[i]), alt[i], color = "green", label = "", markersize = 5)
    p = scatter!(x_pos_utmb.(x_pos[i]), 0, color = "red", label = "")
    #xlims!((x_min, x_max))
    ylims!((0.0, y_max))
    p = plot!(
        [x_pos_utmb.(x_pos[i]); x_pos_utmb.(x_pos[i])],
        [alt[i]; 0],
        lw = 2,
        lc = "red",
        legend = false,
    )
    (v, prob) = particles_prob(cloud)
    #append!(estimated_pos, expectation(identity, cloud))
    #append!(squared_pos, expectation(x->x.^2, cloud))
    quiver!(x_pos_utmb.(v), 2 .+ zero(prob), quiver = (zero(v), prob))
end

function estimate_pos(cloud_iter)
    estimated_pos = []
    var_pos = []
    for cloud in cloud_iter
        current_mean = expectation(x -> x[1], cloud)
        append!(estimated_pos, current_mean)
        append!(var_pos, expectation(x -> delta.(x[1], current_mean)[1]^2, cloud))
    end
    return estimated_pos, var_pos
end

est_speedsbp, var_speedsbp = estimate_pos(cloud_speedsbp_iter)
diff = [delta(x[1], e) for (x, e) in zip(x_pos, est_speedsbp)]
plot(diff)

plot!(var_speedsbp)

plot(cumsum(diff))

est_speed, var_speed = estimate_pos(cloud_speed_iter)
diff_speed = [delta(x[1], e) for (x, e) in zip(x_pos, est_speed)]
plot(diff_speed)
plot(cumsum(diff))
plot!(cumsum(diff_speed))
