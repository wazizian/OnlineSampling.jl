# This 
using Random, Distributions
using OnlineSampling
using Pkg
Pkg.activate("./benchmark/")
using BenchmarkTools, Plots
using Rocket, ReactiveMP, GraphPPL

# Code for the ReactiveMP part is taken from https://github.com/biaslab/ReactiveMP.jl/tree/master/benchmark/notebooks
# We only consider the filtering problem.
# code to obtain more plots has been commented.
# We create model using GraphPPL.jl package interface with @model macro
# For simplicity of the example we consider all matrices to be known and constant
@model function linear_gaussian_ssm_filtering(A, B, P, Q)
    
    # Priors for the previous x_t-1 step
    x_min_t_mean = datavar(Vector{Float64})
    x_min_t_cov  = datavar(Matrix{Float64})
    
    x_min_t ~ MvGaussianMeanCovariance(x_min_t_mean, x_min_t_cov)
    x_t     ~ MvGaussianMeanCovariance(A * x_min_t, P)
    
    y_t = datavar(Vector{Float64})
    y_t ~ MvGaussianMeanCovariance(B * x_t, Q)
    
    return x_min_t_mean, x_min_t_cov, x_t, y_t
end

function generate_data(n, A, B, P, Q; seed = 1234)
    Random.seed!(seed)

    x_prev = zeros(2)
    x      = Vector{Vector{Float64}}(undef, n)
    y      = Vector{Vector{Float64}}(undef, n)

    for i in 1:n
        x[i]   = rand(MvNormal(A * x_prev, P))
        y[i]   = rand(MvNormal(B * x[i], Q))
        x_prev = x[i]
    end
   
    return x, y
end

n = 1000
θ = π / 30
A = [ cos(θ) -sin(θ); sin(θ) cos(θ) ]
B = [ 1.3 0.0; 0.0 0.7 ]
P = [ 0.1 0.0; 0.0 0.1 ]
Q = [ 10.0 0.0; 0.0 10.0 ]
#θ = π / 15

real_x, real_y = generate_data(n, A, B, P, Q);

# Inference procedure for single time step graph and filtering
function reactivemp_inference_filtering(observations, A, B, P, Q)
    n = length(observations) 
    
    model, (x_min_t_mean, x_min_t_cov, x_t, y_t) = linear_gaussian_ssm_filtering(A, B, P, Q)
    
    xbuffer = keep(Marginal)
    
    redirect_to_prior_subscription = subscribe!(getmarginal(x_t), (x_t_posterior) -> begin
        update!(x_min_t_mean, mean(x_t_posterior))
        update!(x_min_t_cov, cov(x_t_posterior))    
    end)
    
    xsubscription = subscribe!(getmarginal(x_t), xbuffer)
    
    update!(x_min_t_mean, [ 0.0, 0.0 ])
    update!(x_min_t_cov, [ 100.0 0.0; 0.0 100.0 ])
    
    for observation in observations
        update!(y_t, observation)
    end
    
    unsubscribe!(xsubscription)
    unsubscribe!(redirect_to_prior_subscription)
    
    return getvalues(xbuffer)
end

#@btime x_reactivemp_filtering_inferred = reactivemp_inference_filtering($real_y, $A, $B, $P, $Q);

x_reactivemp_filtering_inferred = reactivemp_inference_filtering(real_y, A, B, P, Q)

# Visual results verification

#reshape_data(data) = transpose(reduce(hcat, data))
#ylimit = (-20, 20)

#generated_data = plot(1:n, real_x |> reshape_data, label = [ "x[:, 1]" "x[:, 2]" ])
#generated_data = plot!(1:n, real_y |> reshape_data, seriestype = :scatter, ms = 1, alpha = 0.5, label = [ "observations[:, 1]" "observations[:, 2]" ])
#generated_data = plot!(generated_data, legend = :bottomleft, ylimit = ylimit)

#rmp_filtering_results_plot = plot(1:n, real_x |> reshape_data, label = [ "x[:, 1]" "x[:, 2]" ])
#rmp_filtering_results_plot = plot!(rmp_filtering_results_plot, 1:n, mean.(x_reactivemp_filtering_inferred) |> reshape_data, ribbon = var.(x_reactivemp_filtering_inferred) |> reshape_data, label = [ "inferred[:, 1]" "inferred[:, 2]" ])
#rmp_filtering_results_plot = plot!(rmp_filtering_results_plot, legend = :bottomleft, ylimit = ylimit)

#plot(generated_data, rmp_filtering_results_plot, layout = @layout([ a; b ]))

const A_ = [ cos(θ) -sin(θ); sin(θ) cos(θ) ]
const B_ = [ 1.3 0.0; 0.0 0.7 ]
const P_ = [ 0.1 0.0; 0.0 0.1 ]
const Q_ = [ 10.0 0.0; 0.0 10.0 ]

OnlineSampling.@node function model()
    @init x = rand(MvNormal([ 0.0, 0.0 ], [ 100.0 0.0; 0.0 100.0 ]))
    x = rand(MvNormal(A_* @prev(x), P_))
    y = rand(MvNormal(B_ * x, Q_))
    return x, y
end

OnlineSampling.@node function hmm(obs)
    x, y = @nodecall model()
    @observe(y, obs)         
    return x
end

function sbp_inference_filtering(obs)
    n = length(obs)
    cloud = @nodeiter particles = 1 algo = streaming_belief_propagation hmm(Iterators.Stateful(obs))

    dist_onlinesampling_sbp = Vector{Distribution}(undef,n)
    for (i,c) in enumerate(cloud)
        dist_onlinesampling_sbp[i] = dist(c.particles[1])
    end
    return dist_onlinesampling_sbp
end

#@btime dist_onlinesampling_sbp = sbp_inference_filtering($real_y);

dist_onlinesampling_sbp = sbp_inference_filtering(real_y)

#sbp_filtering_results_plot = plot(1:n, real_x |> reshape_data, label = [ "x[:, 1]" "x[:, 2]" ])
#sbp_filtering_results_plot = plot!(sbp_filtering_results_plot, 1:n, mean.(dist_onlinesampling_sbp) |> reshape_data, ribbon = var.(dist_onlinesampling_sbp) |> reshape_data, label = [ "inferred[:, 1]" "inferred[:, 2]" ])
#sbp_filtering_results_plot = plot!(sbp_filtering_results_plot, legend = :bottomleft, ylimit = ylimit)

@assert sum(sum([abs.(delta) for delta in (mean.(x_reactivemp_filtering_inferred) - mean.(dist_onlinesampling_sbp))])) < 0.01

benchmark_rmp_sizes = [ 50, 100, 250, 500, 1_000, 2_000, 5_000, 10_000, 15_000, 20_000, 25_000, 50_000 ];

reactivemp_benchmark_results = map(benchmark_rmp_sizes) do size
    
    benchmark_fitlering = @benchmark reactivemp_inference_filtering(observations, $A, $B, $P, $Q) seconds=30 setup=begin
        states, observations = generate_data($size, $A, $B, $P, $Q);
    end
    
    println("Finished $size for ReactiveMP")
    return (size, benchmark_fitlering)
end


sbp_benchmark_results = map(benchmark_rmp_sizes) do size

    benchmark_fitlering = @benchmark sbp_inference_filtering(observations) seconds=30 setup=begin
        states, observations = generate_data($size, $A, $B, $P, $Q);
    end
    
    println("Finished $size for OnlineSampling")
    return (size, benchmark_fitlering)
end

benchmark_time_ms(trial) = minimum(trial).time / 1_000_000

lgssm_scaling = plot(xscale = :log10, yscale = :log10, xlabel = "Number of observations", ylabel = "Minimum execution time (in ms)", title = "Linear Gaussian State Space Model", legend = :bottomright, size = (650, 400))
lgssm_scaling = plot!(lgssm_scaling, benchmark_rmp_sizes, map(i -> benchmark_time_ms(reactivemp_benchmark_results[i][2]), 1:length(benchmark_rmp_sizes)), markershape = :utriangle, label = "ReactiveMP")
lgssm_scaling = plot!(lgssm_scaling, benchmark_rmp_sizes, map(i -> benchmark_time_ms(sbp_benchmark_results[i][2]), 1:length(benchmark_rmp_sizes)), markershape = :diamond, label = "SBP")

#display(lgssm_scaling)

savefig(lgssm_scaling, "./benchmark/plots/lgssm_scaling.svg")