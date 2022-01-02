#####################################
###       FORWARD OBSERVE         ###
#####################################

"""
    Structure describing a random variable
    that will be potentially observed later
"""
struct TrackedObservation{T,F,S,D<:Distribution{F,S}}
    val::T
    d::D
end

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
    y::TrackedObservation{T,F,S,D},
    obs::T,
) where {T,F,S,D<:Distribution{F,S}}
    return loglikelihood(y.d, obs)
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

unwrap_tracked_type(::Type{TrackedObservation{T,F,S,D}}) where {T,F,S,D} = T
unwrap_tracked_type(::Type{T}) where {T} = T

unwrap_tracked_value(to::TrackedObservation{T,F,S,D}) where {T,F,S,D} = to.val
unwrap_tracked_value(x) = x
