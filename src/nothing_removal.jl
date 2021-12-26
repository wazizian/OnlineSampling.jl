# Propagation of nothing
ftypehasmethod(ftype, argtypes...) =
# Inspired by the code of IRTools.meta
    ftype.name.module === Core.Compiler ||
    ftype <: Core.Builtin ||
    Base._methods_by_ftype(Tuple{ftype,argtypes...}, -1, IRTools.Inner.worldcounter()) |>
    isempty |> (!)

function dummy(args...)
    return
end

IRTools.@dynamo function nothing_dynamo(ftype, argtypes...)
    isapplicable = ftypehasmethod(ftype, argtypes...)
    if !isapplicable
        return IRTools.IR(typeof(dummy), argtypes...)
    end
    ir = IRTools.IR(ftype, argtypes...)
    ir == nothing && return nothing
    IRTools.recurse!(ir)
    return ir
end

nothing_removal(f, args...) = nothing_dynamo(f, args...)
