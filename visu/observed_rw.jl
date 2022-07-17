using OnlineSampling
using PDMats
using Distributions
using LinearAlgebra
using Pkg
Pkg.activate("./visu/")
using Plots
using visu

σ = 1e-10
@node function observed_rw(obs)
    @init x = rand(Normal())
    x = rand(Normal(@prev(x),1.0))
    y = rand(Normal(x,σ))
    @observe(y,obs)
    return x
end

N = 1000
obs = 1:300

function compute_traj_ind(cloud_iter)
    all_x = zeros(N,length(obs))
    ind = zeros(Int,length(obs))
    for (i,cloud) in enumerate(cloud_iter)
        for j=1:N
            x = OnlineSMC.value(cloud.particles[j])
            all_x[j,i]=x
        end
        ind[i]= argmax(cloud.logweights)
    end
    return all_x, ind
end


function create_plot(all_x, ind, period=1)
    p = scatter(1:period:length(obs),obs[1:period:300], label="")
    for i=1:N
        p = plot!(1:length(obs),all_x[i,:], label="")
    end
    p = plot!(1:length(obs),all_x[ind[end],:],lw = 3, c="red", label="")
    return p
end

cloud_iter = @nodeiter particles = N rt = 0.0 observed_rw(obs)
all_x, ind = compute_traj_ind(cloud_iter)
p = create_plot(all_x, ind)
#png(p, "./visu/rw_no_resampling")

cloud_iter = @nodeiter particles = N rt = 1.0 observed_rw(obs)
all_x, ind = compute_traj_ind(cloud_iter)
p = create_plot(all_x, ind)
#png(p, "./visu/rw_with_resampling")

period = 50
@node function observed_rwc(obs)
    @init cpt = 1
    @init x = rand(Normal())
    cpt = @prev(cpt) + 1
    x = rand(Normal(@prev(x),1.0))
    if mod(cpt,period) == 0
        y = rand(Normal(x,1e-8))
        @observe(y,obs)
    end
    return x
end

cloud_iter = @nodeiter particles = N rt = 1.0 observed_rwc(obs)
all_x, ind = compute_traj_ind(cloud_iter)
p = create_plot(all_x, ind,period)
#png(p, "./visu/rw50_with_resampling")


# To get exact distriburtion, 
# we need to 'linearize' our model.
# Here is one way to do that.

period = 100
block = period
csum = LowerTriangular(ones(Float64,block,block))
last = ones(Float64,block)
last = reshape(last, 1, length(last))
@node function rwcond(obs)
    @init x = rand(MvNormal([0.0],1e-8*ScalMat(1, 1.0)))
    dx = rand(MvNormal(zeros(Float64,block), I(block)))
    csumx = rand(MvNormal(csum*dx,1e-8*I(block)))
    y = rand(MvNormal(last*dx, 1e-8*I(1)))
    @observe(y,[obs])
    x = rand(MvNormal(@prev(x)+y, 1e-8*I(1)))
    return dx, csumx
end

delta_obs = [20, 20, 20]
cloud_iter = @nodeiter particles = 1 algo = belief_propagation rwcond(delta_obs)
all_dx = []
all_csum = []
for cloud in cloud_iter
    dx, csumx = OnlineSMC.value(cloud.particles[1])
    #println("x = ", x)
    append!(all_dx,dx)
    append!(all_csum, csumx)
end

scatter([0,100,200,300],cumsum([0, delta_obs...]), label="")
plot!(cumsum(all_dx), label="")

clouds = collect(Iterators.take(cloud_iter,3))

S_full = zeros(Float64,300,300)
for (i,cloud) in enumerate(cloud_iter)
    part = cloud.particles[1]
    d = dist(part)[2]
    S = cov(d)
    S_full[(i-1)*block+1:(i)*block,(i-1)*block+1:(i)*block] = S
end
heatmap(S_full)
#png("./visu/cov_bp")

cov_bridge(s,t,T=100.0) = min(s,t) - s*t/T
S_bridge = zeros(Float64,100,100)
for i=1:100
    for j=1:100
        S_bridge[i,j] = cov_bridge(convert(Float64,i),convert(Float64,j))
    end
end
heatmap(S_bridge)
#png("./visu/cov_bridge")