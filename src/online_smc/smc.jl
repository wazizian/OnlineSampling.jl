"""
    Adaptative resampling step
"""
function resample(
    rng::Random.AbstractRNG,
    threshold::Float64,
    cloud::Cloud,
)
    if ess(cloud) < threshold * length(cloud)
        log_hat_weights, chosen_particles = resample(rng, cloud)
    else
        log_hat_weights = cloud.logweights
        chosen_particles = cloud.particles
    end
    return log_hat_weights, chosen_particles
end

function resample(rng::Random.AbstractRNG, cloud::Cloud)
    chosen_indices = resample_systematic(rng, normalized_weights(cloud))
    chosen_particles = map(chosen_indices) do i
        # TODO (impr, depr?): to avoid the copies here, allow to run a node with a source and 
        # target state
        # TODO (impr): do not copy the particles we have to keep anyway
        # TODO (impr): add a "nocopy" option
        # TODO (impr): parallelize
        # deepcopy(cloud.particles[i])
        cloud.particles[i]
    end
    log_hat_weights = zeros(length(cloud))
    return log_hat_weights, chosen_particles
end

function resample_cloud(cloud::Cloud)::Cloud 
    log_hat_weights, chosen_particles = resample(Random.GLOBAL_RNG, cloud)
    return Cloud(log_hat_weights, chosen_particles)
end

"""
    Sample next state
"""
# TODO: use rng here
function sample_next(
    ::Random.AbstractRNG,
    proposal!::F,
    chosen_particles,
    args::Vararg{Any,N},
) where {F<:Function,N}
    tasks = [Threads.@spawn proposal!(p, args...) for p in chosen_particles]
    return map(fetch, tasks)
end

"""
    Compute the next (normalized) weights
"""
function next_logweights(log_hat_weights::AbstractArray{Float64}, chosen_particles)
    return @. log_hat_weights + loglikelihood(chosen_particles)
end

function smc_step(
    proposal!::F,
    resample_threshold::Float64,
    cloud::Cloud,
    args::Vararg{Any,N};
    rng::Random.AbstractRNG = Random.GLOBAL_RNG,
    #adaptativeresampler::ResampleWithESSThreshold = ResampleWithESSThreshold(),
) where {F<:Function,N}
    #adaptativeresampler = ResampleWithESSThreshold(resample_systematic, resample_threshold)
    log_hat_weights, chosen_particles = resample(rng, resample_threshold, cloud)
    new_particles = sample_next(rng, proposal!, chosen_particles, args...)
    new_logweights = next_logweights(log_hat_weights, new_particles)
    return Cloud(new_logweights, new_particles)
end
