"""
    Adaptative resampling step
"""
function resample(
    rng::Random.AbstractRNG,
    adaptativeresampler::ResampleWithESSThreshold,
    cloud::Cloud,
)
    if ess(cloud) < adaptativeresampler.threshold * length(cloud)
        chosen_indices = adaptativeresampler.resampler(rng, cloud.weights)
        chosen_particles = map(chosen_indices) do i
            # TODO (impr): to avoid the copies here, allow to run a node with a source and 
            # target state
            # TODO (impr): do not copy the particles we have to keep anyway
            deepcopy(cloud.particles[i])
        end
        hat_weights = ones(length(cloud))
    else
        hat_weights = cloud.weights
        chosen_particles = cloud.particles
    end
    return hat_weights, chosen_particles
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
    return map(chosen_particles) do p
        proposal!(p, args...)
    end
end

"""
    Compute the next (normalized) weights
"""
function next_weights(hat_weights::AbstractVector{Float64}, chosen_particles)
    return @. hat_weights * exp(loglikelihood(chosen_particles))
end

function smc_step(
    proposal!::F,
    cloud::Cloud,
    args::Vararg{Any,N};
    rng::Random.AbstractRNG = Random.GLOBAL_RNG,
    adaptativeresampler::ResampleWithESSThreshold = ResampleWithESSThreshold(),
) where {F<:Function,N}
    hat_weights, chosen_particles = resample(rng, adaptativeresampler, cloud)
    new_particles = sample_next(rng, proposal!, chosen_particles, args...)
    new_weights = next_weights(hat_weights, new_particles)
    return Cloud(new_weights, new_particles)
end
