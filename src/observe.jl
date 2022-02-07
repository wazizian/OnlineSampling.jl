#####################################
###       FORWARD OBSERVE         ###
#####################################

"""
    Abstract structure describing a random variable
    that will be potentially observed later
"""
abstract type AbstractTrackedObservation{T,F,S,D<:Distribution{F,S}} end

# Interface
function internal_observe(
    ::AbstractTrackedObservation{T,F,S,D},
    ::T,
)::Float64 where {T,F,S,D} end
function value(::AbstractTrackedObservation{T,F,S,D})::T where {T,F,S,D} end

"""
    Concrete tracked observation structure
"""
struct TrackedObservation{T,F,S,D<:Distribution{F,S}} <: AbstractTrackedObservation{T,F,S,D}
    val::T
    d::D
end

# Satisfy interface 
internal_observe(y::TrackedObservation{T}, obs::T) where {T} =
    Distributions.loglikelihood(y.d, obs)
value(y::TrackedObservation) = y.val

"""
    Exception raised by [internal_observe](@ref) when it encounters an observation
    that is not tracked
"""
struct UntrackedObservation <: Exception end

function internal_observe(val, obs)
    throw(UntrackedObservation())
end

unwrap_tracked_type(U::DataType) = unwrap_type(AbstractTrackedObservation, U)
unwrap_tracked_value(x) = unwrap_value(AbstractTrackedObservation, x)

typeallowstracked(t) = typeallows(AbstractTrackedObservation, t)
