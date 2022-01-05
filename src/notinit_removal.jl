# Propagation of nothing
struct NotInit end

const notinit = NotInit()

function notinit_dummy(args...)
    return notinit
end

"""
    Try to determine if a type can contain a notinit
    If true -> no info
    If false -> there is no notinit
"""
function typeallowsnotinit(@nospecialize t::Type)
    (NotInit <: t) && return true
    isprimitivetype(t) && return false
    (t <: AbstractArray) && return (typeallowsnotinit ∘ eltype)(t)
    isstructtype(t) && return any(typeallowsnotinit, t.types)
    return true
end

"""
    Try to determine if a type must contain notinit
    If true -> there is a notinit
    If false -> no info
"""
function typeforcesnotinit(@nospecialize t::Type)
    (t == NotInit) && return true
    isprimitivetype(t) && return false
    (t <: AbstractArray) && return (typeforcesnotinit ∘ eltype)(t)
    isstructtype(t) && return any(typeforcesnotinit, t.types)
    return false
end

"""
    Determines whether an arbitrary object contains a NotInit
    (Recursive search of the object if it cannot be determinbed based on its type)
"""
@generated function hasnotinit(x)
    # Compile-time fast paths based on type
    if !typeallowsnotinit(x)
        return :(false)
    elseif typeforcesnotinit(x)
        return :(true)
    end

    e = Expr(:||) # default is false
    if hasmethod(Base.iterate, Tuple{x})
        push!(e.args, quote
            Base.any($(@__MODULE__).hasnotinit, x)
        end)
    end
    if isstructtype(x)
        field_calls = [:($(@__MODULE__).hasnotinit(x.$(field))) for field in fieldnames(x)]
        push!(e.args, field_calls...)
    end
    return e
end
hasnotinit(::NotInit) = true

# Manual workarounds
Base.iterate(::A, ::NotInit) where {A<:AbstractArray} = notinit

ftypehasmethod(::Type{typeof(Core.getfield)}, ::Type{NotInit}, args...) = false
