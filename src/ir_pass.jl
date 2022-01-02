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
    Perform a recursive pass on the IR
    - Replace functions which cannot handle notinit with notinit
    - Unwrap TrackedObservation if the function cannot suppport it
"""
dynamo_ir_pass() = nothing
# TODO (impr): submit a PR to IRTools to allow documenting @dynamo functions
@dynamo function ir_pass(ftype, argtypes...)
    isapplicable = ftypehasmethod(ftype, argtypes...)
    if isapplicable
        # best case, continue
        ir = IR(ftype, argtypes...)
        ir == nothing && return fallback(ftype, argtypes...)
        recurse!(ir)
        return ir
    end

    new_argtypes = map(unwrap_tracked_type, argtypes)
    isapplicable = ftypehasmethod(ftype, new_argtypes...)
    anynotiinit = any(t -> t == NotInit, new_argtypes)
    if !isapplicable
        if anynotiinit
            # an argument is not initialized and is causing a failure
            ir = IR(typeof(notinit_dummy), argtypes...)
            return ir
        else
            # programming error, fallback and let the compiler complain
            return fallback(ftype, argtypes...; map_func = :unwrap_tracked_value)
        end
    else
        # TODO (impr): detect when we enter a no reset node so that we do not have
        # to recurse anymore
        ir = IR(ftype, new_argtypes...)
        ir == nothing &&
            return fallback(ftype, argtypes...; map_func = :unwrap_tracked_value)
        # need to both recurse (for notinits) and unwrap arguments
        ir = inline_map_args(ir, :unwrap_tracked_value)
        recurse!(ir)
        return ir
        # if it is a node, we could warn and bypass:
        # using the trick from
        # https://github.com/FluxML/IRTools.jl/blob/948773227955e29a6caae44d109e8be56db6e605/examples/sneakyinvoke.jl
        # to remove the type annotations
    end
end
