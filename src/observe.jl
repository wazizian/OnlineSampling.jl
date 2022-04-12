#####################################
###       FORWARD OBSERVE         ###
#####################################

"""
    Abstract structure describing a random variable
    that will be potentially observed later
"""
abstract type AbstractTrackedObservation{T,F,S,D<:Distribution{F,S}} end

# Interface
function internal_observe(::AbstractTrackedObservation, ::Any)::Float64 end
function value(::AbstractTrackedObservation{T,F,S,D})::T where {T,F,S,D} end
# Alternative value function which might be overriden
function soft_value(obs::AbstractTrackedObservation{T,F,S,D})::T where {T,F,S,D}
    return value(obs)
end

"""
    Concrete tracked observation structure
"""
struct TrackedObservation{T,F,S,D<:Distribution{F,S}} <: AbstractTrackedObservation{T,F,S,D}
    val::T
    d::D
end

# Satisfy interface 
internal_observe(y::TrackedObservation, obs) = Distributions.loglikelihood(y.d, obs)
value(y::TrackedObservation) = y.val

"""
    Exception raised by [internal_observe](@ref) when it encounters an observation
    that is not tracked
"""
struct UntrackedObservation <: Exception
    val::Any
    obs::Any
end

function Base.showerror(io::IO, e::UntrackedObservation)
    msg = """
          Invalid observe statement.
          Observed distribution: $(e.val)::$(typeof(e.val))
          Observation: $(e.obs)::$(typeof(e.obs))
          """
    print(io, msg)
end

# Overloads
Base.:+(to::TrackedObservation, v::AbstractVector) = to.val + v
Base.:+(v::AbstractVector, to::TrackedObservation) = to + v

function internal_observe(val, obs)
    throw(UntrackedObservation(val, obs))
end

unwrap_tracked_type(U::DataType) = unwrap_type(AbstractTrackedObservation, U)
unwrap_tracked_value(x) = unwrap_value(AbstractTrackedObservation, x)
unwrap_soft_tracked_value(x) =
    unwrap_value(AbstractTrackedObservation, x; value = soft_value)

typeallowstracked(t) = typeallows(AbstractTrackedObservation, t)
