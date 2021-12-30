"""
    Build the expr for the fallback to the standard call
    Adapted from IRTools.fallthrough
"""
function fallback(args...; pre_func = nothing, map_func = nothing)
    # Note that here args actually corresponds to [f, args...] in the prev function
    # this is because we have to adhere to the same calling convention as the generated
    # function built by @dynamo, namely
    # https://github.com/FluxML/IRTools.jl/blob/948773227955e29a6caae44d109e8be56db6e605/src/reflection/dynamo.jl#L114
    if map_func == nothing
        call_args = [:(args[$i]) for i = 1:length(args)]
    else
        map_func::Symbol
        call_args = pushfirst!(
            [:($(@__MODULE__).$(map_func)(args[$i])) for i = 2:length(args)],
            :(args[1]),
        )
    end
    if pre_func != nothing
        pre_func::Symbol
        pushfirst!(call_args, :($(@__MODULE__).$(pre_func)))
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
    Recursively apply ir_pass when it cannot be done in ir_pass
"""
dynamo_recurse_ir_pass() = nothing
@dynamo function recurse_ir_pass(ftype, argtypes...)
    ir = IR(ftype, argtypes...)
    ir == nothing && return fallback(ftype, argtypes...)
    recurse!(ir, ir_pass)
    return ir
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
        ir = IR(ftype, new_argtypes...)
        # need to both recurse (for notinits) and unwrap arguments
        # TODO (impr): unwrap the arguments in the IR of f directly
        # TODO (impr): detect when we enter a no reset node so that we do not have
        # to recurse anymore
        return fallback(
            ftype,
            argtypes...;
            pre_func = :recurse_ir_pass,
            map_func = :unwrap_tracked_value,
        )

        # if it is a node, we could warn and bypass:
        # using the trick from
        # https://github.com/FluxML/IRTools.jl/blob/948773227955e29a6caae44d109e8be56db6e605/examples/sneakyinvoke.jl
        # to remove the type annotations
    end
end
