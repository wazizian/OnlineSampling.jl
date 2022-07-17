"""
    Iterator object which represents a top-level call to a node
"""
struct NodeCall{L<:Union{Int,Nothing}}
    f::Any
    ctx::SamplingCtx
    len::L
    #resample_threshold::Float64
    argsiter::Any
end

Base.IteratorSize(nodecall::Type{NodeCall{L}}) where {L} =
    L == Nothing ? Base.SizeUnknown() : Base.HasLength()

Base.length(nodecall::NodeCall{L}) where {L<:Int} = nodecall.len

function Base.iterate(nodecall::NodeCall, state = (nothing, 1, nothing))
    prev_state, t, argsiter_state = state
    reset = t == 1
    (nodecall.len != nothing) && (t > nodecall.len) && return nothing

    next_args =
        reset ? Base.iterate(nodecall.argsiter) :
        Base.iterate(nodecall.argsiter, argsiter_state)
    next_args == nothing && return nothing

    args_val, new_argiter_state = next_args
    new_state, _, val = nodecall.f(prev_state, reset, nodecall.ctx, args_val...)
    return (unwrap_soft_tracked_value(val), (new_state, t + 1, new_argiter_state))
end

"""
    Unfold an iterator and return its last value
"""
function run(iter)
    next = Base.iterate(iter)
    next == nothing && return nothing

    item = first(next)
    while next != nothing
        item, state = next
        next = Base.iterate(iter, state)
    end

    return item
end

"""
    Convenience alias for `Iterators.repeated`
"""
cst(x) = Iterators.repeated(x)

"""
    Given a toplevel call to a node, build the corresponding iterator
"""
function node_iter(macro_args...)
    call = macro_args[end]
    @capture(call, f_(args__)) ||
        error("Improper usage of @nodeiter or @noderun with $(call)")

    # Determine if number of iterations is provided
    n_iterations_expr = :(nothing)
    node_particles = :(0)
    algo = :(particle_filter)
    #iterable = :(false)
    resample_threshold = :(0.5)
    for macro_arg in macro_args
        @capture(macro_arg, T = val_) && (n_iterations_expr = val)
        @capture(macro_arg, particles = val_) && (node_particles = val)
        @capture(macro_arg, algo = val_) && (algo = val)
        @capture(macro_arg, rt = val_) && (resample_threshold = val)
    end

    if node_particles != :(0)
        smc_call = build_smc_call(
            true,
            n_iterations_expr == :(nothing) ? :(nothing) : :(T = $(n_iterations_expr)),
            node_particles,
            algo,
            f,
            resample_threshold,
            args...,
        )
        return esc(smc_call)
    end

    @gensym argsiter_symb len_symb
    argsiter_expr = :(zip($(esc.(args)...)))
    argsiter_len_expr = quote
        (Base.IteratorSize(typeof($argsiter_symb)) isa Base.HasLength) ||
            (Base.IteratorSize(typeof($argsiter_symb)) isa Base.HasShape) ?
        length($argsiter_symb) : nothing
    end

    code = quote
        let $argsiter_symb = $argsiter_expr,
            $len_symb = minimum(
                filter(!isnothing, ($(esc(n_iterations_expr)), $argsiter_len_expr)),
            )

            NodeCall($(esc(f)), SamplingCtx(), $len_symb, $argsiter_symb)
        end
    end
    return code
end

"""
    Returns the IR of the (outer) node function (for testing & debug purposes)
"""
function node_run_ir(macro_args...)
    call = macro_args[end]
    @capture(call, f_(args__)) || error("Improper usage of @node_ir with $(call)")

    full = :(false)
    for macro_arg in macro_args
        @capture(macro_arg, full = val_) && (full = val; break)
    end

    @gensym state_symb i

    map!(arg -> :(first($(esc(arg)))), args, args)
    insert!(args, 1, :($(@__MODULE__).SamplingCtx()))
    insert!(args, 1, :(true))
    insert!(args, 1, :(nothing))

    call = :($(esc(f))($(args...)))
    code = quote
        if $(esc(full))
            println(@macroexpand $(call))
            println(@code_ir $(call))
            @code_llvm optimize = false raw = true $(call)
            @code_native $(call)
        else
            @code_ir $(call)
        end
    end
    return code
end
