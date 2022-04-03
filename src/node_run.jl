function node_run(macro_args...)
    #TODO: handle iterable input, save output...
    call = macro_args[end]
    @capture(call, f_(args__)) || error("Improper usage of @node with $(call)")

    # Determine if number of iterations is provided
    n_iterations_expr = nothing
    node_particles = :(0)
    dsval = bpval = :(false)
    for macro_arg in macro_args
        @capture(macro_arg, T = val_) && (n_iterations_expr = val)
        @capture(macro_arg, particles = val_) && (node_particles = val)
        @capture(macro_arg, DS = val_) && (dsval = val)
        @capture(macro_arg, BP = val_) && (bpval = val)
    end

    if node_particles != :(0)
        smc_call =
            build_smc_call(:(T = $(n_iterations_expr)), node_particles, dsval, bpval, f, args...)
        return esc(smc_call)
    end

    @gensym state_symb reset_symb ctx_symb ret_symb

    map!(esc, args, args)

    init_call = :($(esc(f))(nothing, true, $(ctx_symb), $(args...)))
    call = :($(esc(f))($(state_symb), false, $(ctx_symb), $(args...)))

    body = quote
        $(state_symb), _, _ = $(call)
    end

    # Create main loop
    if isnothing(n_iterations_expr)
        loop_code = quote
            while true
                $(body)
            end
        end
    else
        loop_code = quote
            for _ = 1:($(esc(n_iterations_expr))-2)
                $(body)
            end
        end
    end

    code = quote
        $(ctx_symb) = $(@__MODULE__).SamplingCtx()
        let $(state_symb) = $(init_call)[1]
            $(loop_code)
            _, _, $(ret_symb) = $(call)
            $(ret_symb)
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

    @gensym state_symb

    map!(esc, args, args)
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
