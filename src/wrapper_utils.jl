"""
    Try to determine if a type `t` can contain a type `s`
    If true -> no info
    If false -> there is no `s`
"""
function typeallows(s::Type, @nospecialize t::Type)
    ((s <: t) || (t <: s)) && return true
    (isprimitivetype(t) || t == DataType) && return false
    (t <: AbstractArray) && return typeallows(s, eltype(t))
    hasproperty(t, :types) && return any(u -> (u != t) && typeallows(s, u), t.types)
    return true
end

"""
    Given a type `W` which wraps values of type `T` as `W{T}`,
    unwrap the input type `U` recursively
"""
function unwrap_type(::Type{W}, U::DataType) where {W}
    isempty(U.parameters) && return U
    (U <: W) && return U.parameters[1]
    return U.name.wrapper{map(u -> unwrap_type(W, u), U.parameters)...}
end
unwrap_type(::Type, U::Any) = U

"""
    Given a type `W` which wraps values of type `T` as `W{T}`,
    and which has a method `value(::W{T})::T`, recursively apply
    `value` to the input.
"""
function unwrap_value(w::Type{W}, x; value = value) where {W}
    typeallows(W, typeof(x)) || return x
    # using Accessors
    # https://juliaobjects.github.io/Accessors.jl/stable/docstrings/#Accessors.Properties
    return modify(y -> unwrap_value(W, y, value = value), x, Properties())
end
function unwrap_value(::Type{W}, x::Union{Tuple,AbstractArray}; value = value) where {W}
    typeallows(W, typeof(x)) || return x
    # using Accessors
    # https://juliaobjects.github.io/Accessors.jl/stable/docstrings/#Accessors.Elements()
    return modify(y -> unwrap_value(W, y, value = value), x, Elements())
end

unwrap_value(::Type{W}, x::W; value = value) where {W} = value(x)
