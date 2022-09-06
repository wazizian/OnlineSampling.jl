#####################################
###       FORWARD OBSERVE         ###
#####################################

"""
    Abstract structure describing a random variable
    that will be potentially observed later
"""
abstract type AbstractTrackedObservation{T,F,S,D<:Distribution{F,S}} end

# Interface
"""
    Observe an `AbstractTrackedObservation` and return the loglikelihood
"""
function internal_observe(::AbstractTrackedObservation, ::Any)::Float64 end
"""
    Realize or extract a value from an `AbstractTrackedObservation`. It is 
    called when such a variable is passed to a function which does not support
    the `AbstractTrackedObservation` type.
"""
function value(::AbstractTrackedObservation{T,F,S,D})::T where {T,F,S,D} end
"""
    Realize or extract a value from an `AbstractTrackedObservation`. It is 
    called when such a variable is returned from the inference engine.
"""
function soft_value(obs::AbstractTrackedObservation{T,F,S,D})::T where {T,F,S,D}
    return value(obs)
end
"""
    Notify an `AbstractTrackedObservation` that it is stored to be used as a value for `@prev`
"""
function notify_age(obs::AbstractTrackedObservation)
    return obs
end

"""
    Concrete tracked observation structure
"""
struct TrackedObservation{T,F,S,D<:Distribution{F,S},O<:Union{T, Nothing}} <: AbstractTrackedObservation{T,F,S,D}
    val::T
    d::D
    offset::O
end

TrackedObservation(val::T, d::D) where {T,F,S,D<:Distribution{F,S}} = TrackedObservation{T,F,S,D,Nothing}(val, d, nothing)

function apply_if(pred, func, x, y)
    if pred(y)
        return func(x,y)
    else
        return x
    end
end

# Satisfy interface 
internal_observe(y::TrackedObservation, obs) = Distributions.loglikelihood(y.d, apply_if(!isnothing, -, obs, y.offset))
value(y::TrackedObservation) = apply_if(!isnothing, +, y.val, y.offset)
# notify_age(y::TrackedObservation) = value(y)

"""
    Overload `+` for `TrackedObservation`
"""
Base.:+(y::TrackedObservation, v) = @set y.offset = apply_if(!isnothing, +, v, y.offset)
Base.:+(v, y::TrackedObservation) = y + v

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

function internal_observe(val, obs)
    throw(UntrackedObservation(val, obs))
end

unwrap_tracked_type(U::DataType) = unwrap_type(AbstractTrackedObservation, U)
unwrap_tracked_value(x) = unwrap_value(AbstractTrackedObservation, x)
unwrap_soft_tracked_value(x) =
    unwrap_value(AbstractTrackedObservation, x; value = soft_value)
unwrap_notify_age(x) = unwrap_value(AbstractTrackedObservation, x; value = notify_age)

typeallowstracked(t) = typeallows(AbstractTrackedObservation, t)
