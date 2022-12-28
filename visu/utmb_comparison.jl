using OnlineSampling
using PDMats
using Distributions
using LinearAlgebra
using Pkg
Pkg.activate("./visu/")
using Plots
using visu
using Serialization

ground = ground_utmb
M_speed = 5
drift = 0.01
var_speed = 0.1
speedNoiseStdev = 0.1
plotx = plotx_utmb

max_speed = 10.0
min_speed = 0.0

@node function speed_trail()
    @init speed = M_speed
    speed = max(rand(Normal(@prev(speed), sqrt(var_speed))) - drift, min_speed)
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
last = ones(Float64, block)
last = reshape(last, 1, length(last))
csum = [i for i = block-1:-1:0]
csum = reshape(csum, 1, length(last))

@node function infer(obs, c_speed)
    @init x = rand(MvNormal(startPosX, ScalMat(1, 1e-2)))
    @init speed = rand(MvNormal([M_speed], ScalMat(1, 1e-2)))
    @init observed_speed = c_speed
    @init d_speed = [0.0]
    observed_speed = c_speed
    d_speed = c_speed - @prev(observed_speed)
    speed_noise = rand(MvNormal(zeros(Float64, block), var_speed * I(block)))
    delta = rand(MvNormal(last * speed_noise, ScalMat(1, speedNoiseStdev^2)))
    @observe(delta, d_speed)
    speed = rand(MvNormal(@prev(speed) + last * speed_noise, ScalMat(1, 1e-10)))
    speed_block = block * @prev(speed) + csum * speed_noise
    x = @prev(x) + speed_block
    h = rand(MvNormal(ground.(x), ScalMat(1, measurementNoiseStdev^2)))
    @observe(h, obs)
    return x, h, speed, speed_noise
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

function compare(t, N)
    obs, x_pos, alt, obs_speed, traj_speed = generate_trail(t)
    alt_missing = [alt[i] for i = 1:block:length(obs)]
    speed_missing = [[obs_speed[i]] for i = 1:block:length(obs)]
    x_pos_subsampled = [x_pos[i][1] for i = 1:block:length(obs)]
    cloud_iter = @nodeiter particles = N infer(alt_missing, speed_missing)
    cloud_sbp_iter = @nodeiter particles = N algo = streaming_belief_propagation infer(
        alt_missing,
        speed_missing,
    )

    est, vari = estimate_pos(cloud_iter)
    est_sbp, vari_sbp = estimate_pos(cloud_sbp_iter)
    diff_p = [delta(x[1], e) for (x, e) in zip(x_pos_subsampled, est)]
    diff_sbp = [delta(x[1], e) for (x, e) in zip(x_pos_subsampled, est_sbp)]
    T = sum(cumsum(diff_p) .< t)
    T_sbp = sum(cumsum(diff_sbp) .< t)
    return mean(diff_p), mean(diff_sbp), T, T_sbp
end

N = 2
t = 1000 * block
nbsimu = 1
d_all = []
d_sbp_all = []
T_all = []
T_sbp_all = []
for n = 1:nbsimu
    d, d_sbp, T, T_sbp = compare(t, N)
    println(n, " : ", d, " | ", d_sbp, " times: ", T, " | ", T_sbp)
    append!(d_all, d)
    append!(d_sbp_all, d_sbp)
    append!(T_all, T)
    append!(T_sbp_all, T_sbp)
end

function create_name(name, block = block, N = N, nbsimu = nbsimu)
    st = string(block, '_', N, '_', nbsimu)
    return name * st
end

name_d_all = create_name("visu/simus/d_all")
name_d_sbp_all = create_name("visu/simus/d_sbp_all")
name_T_all = create_name("visu/simus/T_all")
name_T_sbp_all = create_name("visu/simus/T_sbp_all")

println("saving results at ", name_d_all)
Serialization.serialize(name_d_all, d_all)
println("saving results at ", name_d_sbp_all)
Serialization.serialize(name_d_sbp_all, d_sbp_all)
println("saving results at ", name_T_all)
Serialization.serialize(name_T_all, T_all)
println("saving results at ", name_T_sbp_all)
Serialization.serialize(name_T_sbp_all, T_sbp_all)
