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

"""
    Default value implementation
"""
value(p) = p

"""
    Default convenience loglikelihood implementation
"""
loglikelihood(p) = p.loglikelihood

Base.length(cloud::Cloud) = length(cloud.particles)
normalized_weights(cloud::Cloud) = normalize(cloud.weights, 1)

Cloud(particles::P) where {T,P<:AbstractVector{T}} =
    Cloud{T,Vector{Float64},P}(fill(1.0 / length(particles), length(particles)), particles)

"""
    Convenience constructor for Cloud
"""
function Cloud{T}(nparticles::Int) where {T}
    particles = Vector{T}(undef, nparticles)
    # TODO (impr): remove this loop
    for i = 1:nparticles
        particles[i] = T()
    end
    return Cloud(particles)
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
    Assuming that the particles have a method `value`, compute the expectation of `f` applied
    to this value
"""
@inline expectation(f::Function, cloud::Cloud) = _expectation(f ∘ value, cloud)

"""
    Compute an expectation over the cloud of particles, where `f` takes
    a particle as input (and not only its return value)
"""
function _expectation(f::Function, cloud::Cloud{T}) where {T}
    # TODO (question): is the version below faster ?
    # return sum(normalized_weights(cloud) .* f.(cloud.particles))
    return mapreduce((p, w) -> w * f(p), +, cloud.particles, normalized_weights(cloud))
end

"""
    Loglikelihood of a cloud
"""
loglikelihood(cloud::Cloud) = _expectation(loglikelihood, cloud)

"""
    Iterate over the values in a cloud (for testing)
"""
Base.iterate(cloud::Cloud) = Base.iterate(Iterators.map(value, cloud.particles))
Base.iterate(cloud::Cloud, state) =
    Base.iterate(Iterators.map(value, cloud.particles), state)

"""
    Essential Sample Size for adaptative resampling
"""
function ess(normalized_weights::AbstractVector{Float64})
    return 1 ./ sum(normalized_weights .^ 2)
end
ess(cloud::Cloud) = (ess ∘ normalized_weights)(cloud)

"""
    Dummy particle
"""
struct DummyParticle{T}
    val::T
end
value(p::DummyParticle{T}) where {T} = p.val
loglikelihood(::DummyParticle) = 0.0


"""
    Map over particules
"""
