
function node_run(macro_args...)
    #TODO: handle iterable input, save output...
    call = macro_args[end]
    @capture(call, f_(args__)) || error("Improper usage of @node with $(call)")

    # Determine if number of iterations is provided
    n_iterations = nothing
    for macro_arg in macro_args
        @capture(macro_arg, T = val_) && (n_iterations = eval(val); break)
    end
    # Create main loop
    if isnothing(n_iterations)
        loop_creator = body -> quote
            while true
                $(body)
            end
        end
    else
        loop_creator = body -> quote
            for _ = 1:($(n_iterations)-1)
                $(body)
            end
        end
    end

    state_symb = gensym()
    state_type_symb = get_node_mem_struct_type(f)
    reset_symb = gensym()

    map!(esc, args, args)
    for arg in [reset_symb, state_symb]
        insert!(args, 1, arg)
    end

    func_call = quote
        $(esc(f))($(args...))
    end
    loop_code = loop_creator(func_call)

    code = quote
        $(state_symb) = $(esc(state_type_symb))()
        $(reset_symb) = true
        $(func_call)
        $(reset_symb) = false
        $(loop_code)
    end
    return code
end
