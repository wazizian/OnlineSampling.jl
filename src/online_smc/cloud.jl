"""
    Set of particles with their associated weights

    A particle type T is assumed to satisfy the interface
        value : T -> T'
        loglikelihood : T -> Float64
    Note : the loglikelihood method is only needed for SMC
"""
struct Cloud{T,W<:AbstractArray{Float64},P<:AbstractArray{T}}
    logweights::W # not normalized
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
normalized_weights(cloud::Cloud) = softmax(cloud.logweights)

Cloud(particles::P) where {T,P<:AbstractArray{T}} =
    Cloud{T,Vector{Float64},P}(fill(-log(length(particles)), length(particles)), particles)

function Base.show(io::IO, cloud::Cloud)
    print(io, "weights = $(normalized_weights(cloud)), particles = $(cloud.particles)")
end

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
function Base.rand(cloud::Cloud{T,W,P}, n::Integer) where {T,W <: AbstractVector{Float64},P<:AbstractVector{T}}
    return @chain begin
        rand(Distributions.Categorical(normalized_weights(cloud)), n)
        map(i -> value(cloud.particles[i]), _)
        reduce(hcat, _)
    end
end

function Base.rand(cloud::Cloud{T,W,P}, n::Integer) where {T,W,P}
    return Base.rand(Cloud(vec(cloud.logweights), vec(cloud.particles)), n)
end

"""
    Assuming that the particles have a method `value`, compute the expectation of `f` applied
    to this value
"""
expectation(f::Function, cloud::Cloud) = _expectation(f ∘ value, cloud)

"""
    Compute an expectation over the cloud of particles, where `f` takes
    a particle as input (and not only its return value)
"""
function _expectation(f::Function, cloud::Cloud{T}) where {T}
    # TODO (question): is the version below faster ?
    # return mapreduce((p, w) -> w * f(p), +, cloud.particles, normalized_weights(cloud))
    return sum(normalized_weights(cloud) .* f.(cloud.particles))
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
function ess(normalized_weights::AbstractArray{Float64})
    return 1 / norm(normalized_weights, 2)^2
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
