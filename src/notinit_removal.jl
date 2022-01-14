"""
    Represent a value not initialized. Used for the values `@prev x` during resets.
    The current logic at reset time for a call `f(args...)` is roughly teh following:
        
        if applicable(f, args...)
            return f(args...)
        elsif any(hasnotinit, args)
            return notinit
        else
            # proramming error, let the program crash
            return f(args...)
        end
    
    This logic is applied during resets at every function `f` recursively called (be it from this module, `Base`, `Core`...)
    until we reach functions which do not admit a Julia IR.

    Another strategy during resets, which might be simpler, ligter and more robust
    (in particular to incomplete type signatures in `Base`) is the following

        if f in (Core, Base) or has no Julia IR 
            # f is "primitive"
            if any(hasnotinit, args)
                return notinit
            else
                return f(args...)
        else
            if applicable(f, args...)
                return f(args...)
            elsif any(hasnotinit, args)
                return notinit
            else
                # proramming error, let the program crash
                return f(args...)
            end
        end

    (see the [should_instrument](@ref) function)

    However, this is impossible for now since the `store` memories of the nodes contain
    `notinit` at the beginning but legitimate "primitive" operations on them should
    go ahead.
    (Moreover, if we do this, please note that we must still
    recurse in `foreach`, `map`...)

"""
struct NotInit end
const notinit = NotInit()

function notinit_dummy(args...)
    return notinit
end

"""
    Determines whether an arbitrary object contains a NotInit
    (Recursive search of the object if it cannot be determinbed based on its type)
"""
hasnotinit(x) = hastype(NotInit, x)

# Manual workarounds
Base.iterate(::A, ::NotInit) where {A<:AbstractArray} = notinit

ftypehasmethod(::Type{typeof(Core.getfield)}, ::Type{NotInit}, args...) = false
