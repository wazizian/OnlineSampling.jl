# Propagation of nothing
struct NotInit end

const notinit = NotInit()

function notinit_dummy(args...)
    return notinit
end

# Manual workarounds
Base.iterate(::A, ::NotInit) where {A<:AbstractArray} = notinit

ftypehasmethod(::Type{typeof(Core.getfield)}, ::Type{NotInit}, args...) = false
