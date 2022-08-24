# run this file using Julia REPL
using OnlineSampling
using PDMats
using Distributions
using LinearAlgebra
using Pkg
Pkg.activate("./visu/")
using Plots
using visu

ground = ground_utmb
M_speed = 5
drift = 0.01
var_speed = .1
speedNoiseStdev = 0.1
plotx = plotx_utmb

max_speed = 10.
min_speed = 0.

@node function speed_trail()
    @init speed = M_speed
    speed = max(rand(Normal(@prev(speed), sqrt(var_speed)))-drift,min_speed)
    return min(speed, max_speed)
end

@node function true_trail(speed)
    @init x = startPosX
    x = @prev(x) + [speed]
    h = ground.(x)
    h_r = rand(MvNormal(h, ScalMat(1, measurementNoiseStdev^2)))
    speed_r = rand(MvNormal([speed], ScalMat(1, speedNoiseStdev^2)))
    return x, h_r, h, speed_r
end

function generate_trail(t)
    traj_speed = collect(@nodeiter T = t speed_trail())
    traj = collect(@nodeiter true_trail(traj_speed))
    #traj = collect(@nodeiter T=t true_trail())
    obs = [t[2] for t in traj]
    x_pos = [t[1] for t in traj]
    alt = [t[3] for t in traj]
    obs_speed = [t[end][1] for t in traj]
    return obs, x_pos, alt, obs_speed, traj_speed
end

block = 5
t = 1000*block
obs, x_pos, alt, obs_speed, traj_speed = generate_trail(t)


mult_var = sum(1:block-1)
last = ones(Float64,block)
last = reshape(last, 1, length(last))
csum = [i for i=block-1:-1:0]
csum = reshape(csum, 1, length(last))

@node function infer(obs , c_speed)
    @init x = rand(MvNormal(startPosX, ScalMat(1, 1e-2)))
    @init speed = rand(MvNormal([M_speed], ScalMat(1, 1e-2)))
    @init observed_speed = c_speed
    @init d_speed = [0.0]
    observed_speed = c_speed
    d_speed = c_speed - @prev(observed_speed)
    speed_noise = rand(MvNormal(zeros(Float64,block), var_speed*I(block)))
    delta = rand(MvNormal(last*speed_noise, ScalMat(1,speedNoiseStdev^2)))
    @observe(delta,d_speed)
    speed = rand(MvNormal(@prev(speed) +last*speed_noise, ScalMat(1, 1e-10)))
    speed_block = block*@prev(speed) + csum*speed_noise
    x = @prev(x)+speed_block
    h = rand(MvNormal(ground.(x), ScalMat(1, measurementNoiseStdev^2)))
    @observe(h,obs)
    return x, h, speed, speed_noise
end

N = 20
alt_missing = [alt[i] for i=1:block:length(obs)]
speed_missing = [[obs_speed[i]] for i=1:block:length(obs)]
cloud_sbp_iter = @nodeiter particles = N algo = streaming_belief_propagation infer(alt_missing,speed_missing)
cloud_iter = @nodeiter particles = N infer(alt_missing,speed_missing)

all_x_mean = []
all_speed_mean = []
for (i, cloud) in enumerate(cloud_sbp_iter)
    (v, prob) = particles_prob(cloud)
    append!(all_x_mean, mean(v))
    append!(all_speed_mean, sum(prob .* [mean(dist(p)[3]) for p in cloud.particles]))
end
all_x_mean_p = []
all_speed_mean_p = []
for (i, cloud) in enumerate(cloud_iter)
    (v, prob) = particles_prob(cloud)
    append!(all_x_mean_p, mean(v))
    append!(all_speed_mean_p, sum(prob .* [mean(dist(p)[3]) for p in cloud.particles]))
end

plot(all_x_mean,all_speed_mean, label="sbp")
plot!(all_x_mean_p,all_speed_mean_p, label = "part")
plot!([x_pos[i][1] for i=1:block:length(obs)], [traj_speed[i] for i=1:block:length(obs)], label="truth")


@gif for (i, cloud) in enumerate(cloud_sbp_iter)
    p = plot(plotx, ground.(plotx), label = "")
    p = scatter!(x_pos_utmb.(x_pos[(i-1)*block+1]), alt[(i-1)*block+1], color = "green", label = "", markersize = 5)
    p = scatter!(x_pos_utmb.(x_pos[(i-1)*block+1]), 0, color = "red", label = "")
    ylims!((0.0, 2))
    p = plot!([x_pos_utmb.(x_pos[(i-1)*block+1]); x_pos_utmb.(x_pos[(i-1)*block+1])], [alt[(i-1)*block+1]; 0], lw = 2, lc = "red", legend = false)
    (v, prob) = particles_prob(cloud)
    quiver!(x_pos_utmb.(v), 1 .+ zero(prob), quiver = (zero(v), prob))
end


@gif for (i, cloud) in enumerate(cloud_iter)
    p = plot(plotx, ground.(plotx), label = "")
    p = scatter!(x_pos_utmb.(x_pos[(i-1)*block+1]), alt[(i-1)*block+1], color = "green", label = "", markersize = 5)
    p = scatter!(x_pos_utmb.(x_pos[(i-1)*block+1]), 0, color = "red", label = "")
    ylims!((0.0, 2))
    p = plot!([x_pos_utmb.(x_pos[(i-1)*block+1]); x_pos_utmb.(x_pos[(i-1)*block+1])], [alt[(i-1)*block+1]; 0], lw = 2, lc = "red", legend = false)
    (v, prob) = particles_prob(cloud)
    quiver!(x_pos_utmb.(v), 1 .+ zero(prob), quiver = (zero(v), prob))
end

@gif for (i, cloud) in enumerate(cloud_sbp_iter)
    p = plot(polar_x_pos.(plotx), ground.(plotx), proj=:polar, label = "",showaxis=false)
    p = scatter!(polar_x_pos.(x_pos[(i-1)*block+1]), alt[(i-1)*block+1], color = "green", proj=:polar, label = "", markersize = 5)
    ylims!((0.0, 1.3))
    p = plot!([polar_x_pos.(x_pos[(i-1)*block+1]); polar_x_pos.(x_pos[(i-1)*block+1])], [alt[(i-1)*block+1]; 0], lw = 2, lc = "red", proj=:polar, legend = false)
    (v, prob) = particles_prob(cloud)
    quiver!(polar_x_pos.(v), 1 .+ zero(prob), proj=:polar, quiver = (zero(v), 0.3*prob))
end

# to save replace @gif above by anim = @animate and uncomment:
#gif(anim, "./visu/plots/trail_sbp_polar_fps30.gif", fps = 30)