"""
    Build the expr for the fallback to the standard call
    Adapted from IRTools.fallthrough
"""
function fallback(args...; map_func = nothing, mod = @__MODULE__)
    # Note that here args actually corresponds to [f, args...] in the prev function
    # this is because we have to adhere to the same calling convention as the generated
    # function built by @dynamo, namely
    # https://github.com/FluxML/IRTools.jl/blob/948773227955e29a6caae44d109e8be56db6e605/src/reflection/dynamo.jl#L114

    if map_func == nothing
        call_args = [:(args[$i]) for i = 1:length(args)]
    else
        map_func::Symbol
        call_args =
            pushfirst!([:($(mod).$(map_func)(args[$i])) for i = 2:length(args)], :(args[1]))
    end
    code = push_front(
        # advise the compiler to inline following the code
        # of IRTools.fallthrough
        Expr(:meta, :inline),
        Expr(:call, call_args...),
    )
    # return an Expr
    return code
end

"""
    Determine whether we should instrument this ir
"""
should_instrument(::Nothing) = false
should_instrument(ir::IR) = !is_node(ir)

"""
    Perform a recursive pass on the IR
    - Replace functions which cannot handle notinit with notinit
    - Unwrap TrackedObservation if the function cannot suppport it
"""
# Exception for `println` and `show`
# to have unaltered info during debug
irpass(g::Union{typeof(Base.println),typeof(Base.show)}, args...) = g(args...)

@dynamo function irpass(ftype, argtypes...)
    # @show (ftype, argtypes...)
    isapplicable = ftypehasmethod(ftype, argtypes...)
    if isapplicable
        # best case, continue
        ir = IR(ftype, argtypes...)
        should_instrument(ir) || return fallback(ftype, argtypes...)
        if is_reset_node(ir)
            ir = propagate_notinits!(ir)
        end
        if typeallowstracked(ftype) || any(typeallowstracked, argtypes)
            recurse!(ir)
        end
        return ir
    end

    # cannot propagate obs
    new_argtypes = map(unwrap_tracked_type, argtypes)
    ir = IR(ftype, new_argtypes...)
    should_instrument(ir) ||
        return fallback(ftype, argtypes...; map_func = :unwrap_tracked_value)
    if is_reset_node(ir)
        ir = propagate_notinits!(ir)
    end
    ir = inline_map_args!(ir, :unwrap_tracked_value)
    # no need to recurse (no tracked rev anymore)
    return ir
end
