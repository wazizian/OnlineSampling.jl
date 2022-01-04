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
function sample_next!(::Random.AbstractRNG, proposal!::Function, chosen_particles)
    foreach(proposal!, chosen_particles)
end

"""
    Compute the next (normalized) weights
"""
function next_weights(hat_weights::AbstractVector{Float64}, chosen_particles)
    return normalize(hat_weights .* exp.(loglikelihood.(chosen_particles)), 1)
end

function smc_step(
    proposal!::Function,
    cloud::Cloud;
    rng::Random.AbstractRNG = Random.GLOBAL_RNG,
    adaptativeresampler::ResampleWithESSThreshold = ResampleWithESSThreshold(),
)
    hat_weights, chosen_particles = resample(rng, adaptativeresampler, cloud)
    sample_next!(rng, proposal!, chosen_particles)
    new_weights = next_weights(hat_weights, chosen_particles)
    return Cloud(new_weights, chosen_particles)
end
