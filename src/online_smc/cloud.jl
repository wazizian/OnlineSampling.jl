"""
    Set of particles with their associated weights

    A particle type T is assumed to satisfy the interface
        value : T -> T'
        loglikelihood : T -> Float64
"""
struct Cloud{T,W<:AbstractVector{Float64},P<:AbstractVector{T}}
    weights::W # not normalized
    particles::P
end
Base.length(cloud::Cloud) = length(cloud.particles)
normalized_weights(cloud::Cloud) = normalize(cloud.weights, 1)

function value(_) end
function loglikelihood(_) end

Cloud(particles::P) where {T,P<:AbstractVector{T}} =
    Cloud{T,Vector{Float64},P}(fill(1.0 / length(particles), length(particles)), particles)

"""
    Convenience constructor for Cloud
"""
# TODO (impr): use static arrays for speed
@generated function Cloud(nparticles::Int, ::Type{T}) where {T}
    particles_array = quote
        particles = Vector{$(T)}(undef, nparticles)
        for i = 1:nparticles
            particles[i] = $(T)()
        end
        particles
    end
    return :(Cloud($(particles_array)))
end

"""
    Testing function
"""
function Base.rand(cloud::Cloud{T,W,P}, n::Integer) where {T,W,P}
    return @chain begin
        rand(Distributions.Categorical(normalized_weights(cloud)), n)
        map(i -> value(cloud.particles[i]), _)
        reduce(hcat, _)
    end
end

"""
    Assuming that the particles have a field value, compute the expectation of f applied
    to this value
"""
function expectation(f::Function, cloud::Cloud{T}) where {T}
    # TODO (question): is the version below faster ?
    # return sum(normalized_weights(cloud) .* (f ∘ value).(cloud.particles))
    return mapreduce(
        (p, w) -> w * f(value(p)),
        +,
        cloud.particles,
        normalized_weights(cloud),
    )
end

"""
    Essential Sample Size for adaptative resampling
"""
function ess(normalized_weights::AbstractVector{Float64})
    return 1 ./ sum(normalized_weights .^ 2)
end
ess(cloud::Cloud) = (ess ∘ normalized_weights)(cloud)
