# Propagation of nothing

ftypehasmethod(ftype, argtypes...) =
# Determines if the function f whose type is ftype has a method
# for arguments of types argtypes
# Inspired by the code of IRTools.meta
    ftype.name.module === Core.Compiler ||
    ftype <: Core.Builtin ||
    Base._methods_by_ftype(Tuple{ftype,argtypes...}, -1, IRTools.Inner.worldcounter()) |>
    isempty |> (!)

function dummy(args...)
    return
end

@dynamo function nothing_dynamo(ftype, argtypes...)
    @assert ftype != typeof(nothing_dynamo)
    isapplicable = ftypehasmethod(ftype, argtypes...)
    # @show (ftype, argtypes, isapplicable)
    if !isapplicable
        return IR(typeof(dummy), argtypes...)
    end
    ir = IR(ftype, argtypes...)
    ir == nothing && return nothing
    # @show ir
    recurse!(ir)
    return ir
end

nothing_removal(f, args...) = nothing_dynamo(f, args...)

# Manual workarounds
Base.iterate(::A, ::Nothing) where {A<:AbstractArray} = nothing
