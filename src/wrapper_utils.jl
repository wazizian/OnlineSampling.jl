"""
    Try to determine if a type `t` can contain a type `s`
    If true -> no info
    If false -> there is no `s`
"""
function typeallows(s::Type, @nospecialize t::Type)
    ((s <: t) || (t <: s)) && return true
    isprimitivetype(t) && return false
    (t <: AbstractArray) && return typeallows(s, eltype(t))
    hasproperty(t, :types) && return any(u -> typeallows(s, u), t.types)
    return true
end

"""
    Try to determine if a type `t` must contain a type `s`
    If true -> there is a `s`
    If false -> no info
"""
function typeforces(s::Type, @nospecialize t::Type)
    (t <: s) && return true
    isprimitivetype(t) && return false
    (t <: AbstractArray) && return typeforces(s, eltype(t))
    hasproperty(t, :types) && return any(u -> typeforces(s, u), t.types)
    return false
end

"""
    Determines whether an arbitrary object contains a value of type `s`
    (Recursive search of the object if it cannot be determinbed based on its type)
"""
@generated function hastype(s::Type{T}, x) where {T}
    # Compile-time fast paths based on type
    if !typeallows(T, x)
        return :(false)
    elseif typeforces(T, x)
        return :(true)
    end

    e = Expr(:||) # default is false
    if hasmethod(Base.iterate, Tuple{x})
        push!(e.args, quote
            for y in x
                $(@__MODULE__).hastype(s, y) && return true
            end
            false
        end)
    end
    if isstructtype(x)
        field_calls = [:($(@__MODULE__).hastype(s, x.$(field))) for field in fieldnames(x)]
        push!(e.args, field_calls...)
    end
    return e
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
    `value` to the input
"""
function unwrap_value(w::Type{W}, x) where {W}
    typeallows(W, typeof(x)) || return x
    # using Accessors
    # https://juliaobjects.github.io/Accessors.jl/stable/docstrings/#Accessors.Properties
    return modify(y -> unwrap_value(W, y), x, Properties())
end
function unwrap_value(::Type{W}, x::Union{Tuple,AbstractArray}) where {W}
    typeallows(W, typeof(x)) || return x
    # using Accessors
    # https://juliaobjects.github.io/Accessors.jl/stable/docstrings/#Accessors.Elements()
    return modify(y -> unwrap_value(W, y), x, Elements())
end

unwrap_value(::Type{W}, x::W) where {W} = value(x)
