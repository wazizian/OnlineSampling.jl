function build_call(f, args...)
    return :($(f)($(args...)))
end

function node_run(macro_args...)
    #TODO: handle iterable input, save output...
    call = macro_args[end]
    @capture(call, f_(args__)) || error("Improper usage of @node with $(call)")

    # Determine if number of iterations is provided
    n_iterations_expr = nothing
    for macro_arg in macro_args
        @capture(macro_arg, T = val_) && (n_iterations_expr = val; break)
    end

    # Create main loop
    if isnothing(n_iterations_expr)
        loop_creator = body -> quote
            while true
                $(body)
            end
        end
    else
        loop_creator = body -> quote
            for _ = 1:($(esc(n_iterations_expr))-1)
                $(body)
            end
        end
    end

    state_symb = gensym()
    state_type_symb = get_node_mem_struct_type(f)
    reset_symb = gensym()
    ctx_symb = gensym()

    map!(esc, args, args)
    for arg in [ctx_symb, reset_symb, state_symb]
        insert!(args, 1, arg)
    end

    func_call = build_call(esc(f), args...)
    loop_code = loop_creator(func_call)

    code = quote
        $(state_symb) = $(esc(state_type_symb))()
        $(reset_symb) = true
        $(ctx_symb) = $(@__MODULE__).SamplingCtx()
        $(func_call)
        $(reset_symb) = false
        $(loop_code)
    end
    return code
end

"""
    Returns the IR of the (outer) node function (for testing & debug purposes)
"""
function node_run_ir(macro_args...)
    call = macro_args[end]
    @capture(call, f_(args__)) || error("Improper usage of @node_ir with $(call)")

    irpass = :(true)
    for macro_arg in macro_args
        @capture(macro_arg, irpass = val_) && (irpass = val; break)
    end

    full = :(false)
    for macro_arg in macro_args
        @capture(macro_arg, full = val_) && (full = val; break)
    end

    state_symb = gensym()
    state_type_symb = get_node_mem_struct_type(f)

    map!(esc, args, args)
    insert!(args, 1, :($(@__MODULE__).SamplingCtx()))
    insert!(args, 1, true)
    insert!(args, 1, state_symb)

    ir_func_call = build_call(esc(f), args...)
    code = quote
        $(state_symb) = $(esc(state_type_symb))()
        if $(esc(irpass))
            if $(esc(full))
                println(@macroexpand $(ir_func_call))
                println(@code_ir $(ir_func_call))
                @code_llvm optimize = false raw = true $(ir_func_call)
                @code_native $(ir_func_call)
            else
                @code_ir $(ir_func_call)
            end
        else
            @code_ir $(esc(f))($(args...))
        end
    end
    return code
end
