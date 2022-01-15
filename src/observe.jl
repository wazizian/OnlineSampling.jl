#####################################
###       FORWARD OBSERVE         ###
#####################################

"""
    Abstract structure describing a random variable
    that will be potentially observed later
"""
abstract type AbstractTrackedObservation{T,F,S,D<:Distribution{F,S}} end

# Interface
function loglikelihood(::AbstractTrackedObservation{T,F,S,D}, ::T)::Float64 where {T,F,S,D} end
function value(::AbstractTrackedObservation{T,F,S,D})::T where {T,F,S,D} end

"""
    Concrete tracked observation structure
"""
struct TrackedObservation{T,F,S,D<:Distribution{F,S}} <: AbstractTrackedObservation{T,F,S,D}
    val::T
    d::D
end

# Satisfy interface 
loglikelihood(y::TrackedObservation{T}, obs::T) where {T} =
    Distributions.loglikelihood(y.d, obs)
value(y::TrackedObservation) = y.val

"""
    Exception raised by [internal_observe](@ref) when it encounters an observation
    that is not tracked
"""
struct UntrackedObservation <: Exception end

"""
    [@observe](@ref) macros ultimately result in calls to
    this function
"""
function internal_observe(
    y::AbstractTrackedObservation{T,F,S,D},
    obs::T,
) where {T,F,S,D<:Distribution{F,S}}
    return loglikelihood(y, obs)
end

function internal_observe(val, obs)
    throw(UntrackedObservation())
end

"""
    Wrap a sampled value in a TrackedObservation
"""
# TODO (impr): add support for dim argument and rng
function internal_rand(d::Distribution)
    return TrackedObservation(rand(d), d)
end

unwrap_tracked_type(U::DataType) = unwrap_type(AbstractTrackedObservation, U)
unwrap_tracked_value(x) = unwrap_value(AbstractTrackedObservation, x)
