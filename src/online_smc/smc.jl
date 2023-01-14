"""
    Adaptative resampling step
"""
function resample(
    rng::Random.AbstractRNG,
    adaptativeresampler::ResampleWithESSThreshold,
    cloud::Cloud,
)
    if ess(cloud) < adaptativeresampler.threshold * length(cloud)
        chosen_indices = adaptativeresampler.resampler(rng, normalized_weights(cloud))
        chosen_particles = map(chosen_indices) do i
            # TODO (impr): to avoid the copies here, allow to run a node with a source and 
            # target state
            # TODO (impr): do not copy the particles we have to keep anyway
            deepcopy(cloud.particles[i])
        end
        log_hat_weights = zeros(length(cloud))
    else
        log_hat_weights = cloud.logweights
        chosen_particles = cloud.particles
    end
    return log_hat_weights, chosen_particles
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
    adaptativeresampler = ResampleWithESSThreshold(resample_systematic, resample_threshold)
    log_hat_weights, chosen_particles = resample(rng, adaptativeresampler, cloud)
    new_particles = sample_next(rng, proposal!, chosen_particles, args...)
    new_logweights = next_logweights(log_hat_weights, new_particles)
    return Cloud(new_logweights, new_particles)
end
