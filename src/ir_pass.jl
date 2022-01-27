"""
    (Experimental & Unused for now) Specify modules which should not
    be instrumented at this stage
"""
# TODO (impr): next overhaul of the notinit system
# do not put notinit in the struct but nothing, and change @prev calls at reset
# then we can safely use the function below, and the commented lines below
# (so that we can use fallback even with ops on the store struct (which rn may
# contain notinits and not pass the hasnotinit test))
should_instrument(ftype::DataType, ::IR) = !(ftype.name.module in (Base, Core))
should_instrument(::DataType, ::Nothing) = false

"""
    Build the expr for the case when the current function
    cannot be applied to its current arguments, or is primitive. If in reset
    and one of the arguments is not properly initialized,
    return notinit
"""
function fallback(args...; map_func = nothing, mode = @__MODULE__)
    # Note that here args actually corresponds to [f, args...] in the prev function
    # this is because we have to adhere to the same calling convention as the generated
    # function built by @dynamo, namely
    # https://github.com/FluxML/IRTools.jl/blob/948773227955e29a6caae44d109e8be56db6e605/src/reflection/dynamo.jl#L114

    # if there is an initialized argument and we are in reset
    #   return notinit
    # o/w let the program crash or continue
    code = quote
        # TODO (impr): resolve the first condition at compile-time
        if $(@__MODULE__).isreset(irpass) && any($(@__MODULE__).hasnotinit, args)
            return $(@__MODULE__).notinit
        else
            $(fallback_original_call(args...; map_func = map_func, mod = mod))
        end
    end
    return code
end

"""
    Build the expr for the fallback to the standard call
    Adapted from IRTools.fallthrough
"""
function fallback_original_call(args...; map_func = nothing, mod = @__MODULE__)
    # Same note as above for args
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

struct IRPass
    reset::Bool
end
IRPass() = IRPass(false)
isreset(irpass::IRPass) = irpass.reset

"""
    Check if the IR is a reset node, and, if it is, recurse with
    reset = true
"""
function adaptative_recurse!(ir::IR)
    if is_reset_node(ir)
        new_self = pushfirst!(ir, Statement(Expr(:block)))
        recurse!(ir, new_self)
        ir[new_self] =
            Statement(xcall(@__MODULE__, :IRPass, :(true)); type = (@__MODULE__).IRPass)
    else
        recurse!(ir)
    end
end

"""
    Perform a recursive pass on the IR
    - Replace functions which cannot handle notinit with notinit
    - Unwrap TrackedObservation if the function cannot suppport it
"""
ir_pass(f, args...) = IRPass()(f, args...)

@dynamo function (irpass::IRPass)(ftype, argtypes...)
    # @show (ftype, argtypes...)
    isapplicable = ftypehasmethod(ftype, argtypes...)
    if isapplicable
        # best case, continue
        ir = IR(ftype, argtypes...)
        ir == nothing && return fallback_original_call(ftype, argtypes...)
        # see top TODO
        # should_instrument(ftype, ir) || return fallback(ftype, argtypes...)
        adaptative_recurse!(ir)
        return ir
    end
    # cannot propagate obs

    new_argtypes = map(unwrap_tracked_type, argtypes)
    isapplicable = ftypehasmethod(ftype, new_argtypes...)
    if !isapplicable
        return fallback(ftype, argtypes...)
    else
        ir = IR(ftype, new_argtypes...)
        ir == nothing &&
            return fallback(ftype, argtypes...; map_func = :unwrap_tracked_value)
        # see top TODO
        # should_instrument(ftype, ir) ||
        #     return fallback(ftype, argtypes...; map_func = :unwrap_tracked_value)

        # need to both recurse (for notinits) and unwrap arguments
        adaptative_recurse!(ir)
        ir = inline_map_args!(ir, :unwrap_tracked_value)
        return ir
        # if it is a node, we could warn and bypass:
        # using the trick from
        # https://github.com/FluxML/IRTools.jl/blob/948773227955e29a6caae44d109e8be56db6e605/examples/sneakyinvoke.jl
        # to remove the type annotations
    end
end

"""
    Modification of `IRTools.recurse!` to properly handle 
    `Core._apply` and `Core._apply_iterate`
"""
# Related Issues
# https://github.com/FluxML/IRTools.jl/issues/74
# https://github.com/JuliaLabs/Cassette.jl/issues/146
# https://github.com/JuliaLabs/Cassette.jl/issues/162
# The current workaround is inspired by Zygote
# https://github.com/FluxML/Zygote.jl/blob/3a63df8edb3b613107761ff829ca61ed393ce2dd/src/lib/lib.jl#L188
function recurse!(ir, to = self)
    for (x, st) in ir
        isexpr(st.expr, :call) || continue
        if length(st.expr.args) ≥ 2 &&
           st.expr.args[1] == GlobalRef(Core, :_apply_iterate) &&
           st.expr.args[2] == GlobalRef(Base, :iterate)
            funcarg = insert!(ir, x, xcall(:tuple, st.expr.args[3]))
            ir[x] = xcall(Core, :_apply, to, funcarg, st.expr.args[4:end]...)
        elseif st.expr.args[1] == GlobalRef(Core, :_apply)
            funcarg = insert!(ir, x, xcall(:tuple, st.expr.args[2]))
            ir[x] = xcall(Core, :_apply, to, funcarg, st.expr.args[3:end]...)
        else
            ir[x] = Expr(:call, to, st.expr.args...)
        end
    end
    return ir
end
# Equivalent to the following
# (irpass::IRPass)(::typeof(Core._apply_iterate), ::typeof(Base.iterate), f, args...) =
#     Core._apply(irpass, (f,), args...)

# (irpass::IRPass)(::typeof(Core._apply), f, args...) = Core._apply(irpass, (f,), args...)

"""
    Exception for `println` and `show`
    to have unaltered info during debug
"""
(irpass::IRPass)(g::Union{typeof(Base.println),typeof(Base.show)}, args...) = g(args...)
