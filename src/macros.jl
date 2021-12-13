global node_counter = 0

function sh(body)
    return println(prettify(body))
end

function push_front(ex, body)
    return quote
        $(ex)
        $(body)
    end
end

function stopwalk(f, x::Expr)
    # Walk the AST of x
    # If f(x) = nothing, continue recursively on x's children
    # Otherwise, the walk stops
    # Note that f is given the ability to call the walk itself
    # (Inspired by the walk function from MacroTools)
    self = x -> stopwalk(f, x)
    y = f(self, x)
    return isnothing(y) ? Expr(x.head, map(x -> stopwalk(f, x), x.args)...) : y
end
# Ignore x if not an exp
stopwalk(f, x) = x

function treat_initialized_vars(reset_symb::Symbol, body::Expr)::Expr
    # This is a naive reference imple
    # TODO (impr) create a reset func and dispatch

    initialized_vars = Set{Symbol}()

    new_body = @chain body begin
        # Collect initalized variables
        postwalk(_) do ex
            @capture(ex, @init var_ = val_) && push!(initialized_vars, var)
            return ex
        end
        # make sure we do not try to assign to the var when we reset
        stopwalk(_) do walk, ex
            # important, do not modify special init assignments
            @capture(ex, @init var_ = val_) && return quote @init $(walk(var)) = $(walk(val)) end
            @capture(ex, var_ = val_) && var in initialized_vars && return quote
                $(reset_symb) ? $(walk(val)) : $(walk(var)) = $(walk(val))
            end
            return nothing
        end
        # init
        postwalk(_) do ex
            @capture(ex, @init var_ = val_) || return ex
            return quote
                $(reset_symb) ? $(var) = $(val) : $(val)
            end
        end
    end

    # make sure there are no init left
    postwalk(new_body) do ex
        @capture(ex, @init _) && error("Ill formed @init: found $(ex)")
    end

    return new_body
end

function treat_node_calls(state_symb::Symbol, reset_symb::Symbol, body::Expr)::Expr
    new_body = postwalk(body) do ex
        @capture(ex, (@node cond_ f_(args__)) | (@node f_(args__))) || return ex

        # get new id
        global node_counter
        node_counter += 1
        id = node_counter

        # integrate reset condition
        reset_cond = isnothing(cond) ? reset_symb : :($(reset_symb) || $(cond))
        for arg in [reset_cond, id, state_symb]
            insert!(args, 1, arg)
        end
        return quote $(f)($(args...)) end
    end

    # make sure there are no init left
    prewalk(new_body) do ex
        @capture(ex, @node) && error("Ill formed @node call inside node: found $(ex)")
    end

    return new_body
end

function treat_stored_variables(state_symb::Symbol, func_id_symb::Symbol, reset_symb::Symbol, store_symb::Symbol, body::Expr)::Tuple{Expr, Expr}
    # Collect stored variables and insert call to store
    stored_vars = Set{Symbol}()
    new_body = @chain body begin
        postwalk(_) do ex
            @capture(ex, (@prev e_) | (@prev(e_)) ) || return ex
            isexpr(e, Symbol) || error("@prev can only be applied to a variable (for now), but found $(ex)")
            push!(stored_vars, e)
            return quote $(store_symb).$(e) end
        end

        # store the values for the next time step
        postwalk(_) do ex
            (@capture(ex, var_ = val_ ) && var in stored_vars) || return ex
            pre_set_expr = quote setproperties($(esc(store_symb)), $(esc(var)) = deepcopy($(esc(var)))) end
            set_expr = Expr(Symbol("hygienic-scope"), pre_set_expr, @__MODULE__)
            return quote
                begin
                    $(var) = $(val)
                    # TODO (bug): do not use a copy here but after the node call
                    $(state_symb).nodestates[$(func_id_symb)] = $(set_expr)
                    $(var)
                end
            end
        end
    end

    # make sure there are no prev left
    prewalk(new_body) do ex
        @capture(ex, @prev _) && error("Ill formed @prev call inside node: found $(ex)")
    end

    # TODO (impr) use type info
    # Build stored struct
    # (to be inserted before func)
    struct_symb = gensym()
    # TODO (bug) use the line below and propagate nothings with cassette 
    # init_stored_vars = Vector{Nothing}(nothing, length(stored_vars))
    init_stored_vars = zeros(Int64, length(stored_vars))
    struct_def = quote
        # I don't know why by $(struct_symb) is already escaped below
        struct $(struct_symb)
            $(stored_vars...)
        end
    end
    # add the constructore only is stored_vars != emptyset
    full_struct_def = isempty(stored_vars) ? struct_def : quote
        $(struct_def)
        # constructor
        $(struct_symb)() = $(struct_symb)($(init_stored_vars...))
    end

    # Build reset code
    reset_code = quote
        $(reset_symb) && ($(state_symb).nodestates[$(func_id_symb)] = $(struct_symb)())
    end

    return full_struct_def, push_front(reset_code, new_body)
end

macro node(args...)
    @assert !isempty(args)
    func = args[end]
    splitted = nothing
    try
        splitted = splitdef(func)
    catch AssertionError
        return node_run(args...)
    end
    return node_build(splitted)
end

function node_build(splitted)
    # Modify arguments
    state_symb = gensym()
    func_id_symb = gensym()
    reset_symb = gensym()
    # TODO (impr) : add types
    for symb in [reset_symb, func_id_symb, state_symb]
        insert!(splitted[:args], 1, symb)
    end

    body = splitted[:body]

    store_symb = gensym()
    assign_store = quote
        $(store_symb) = $(state_symb).nodestates[$(func_id_symb)]
    end

    struct_def, new_body = @chain body begin
        push_front(assign_store, _)
        treat_initialized_vars(reset_symb, _)
        treat_node_calls(state_symb, reset_symb, _)
        treat_stored_variables(state_symb, func_id_symb, reset_symb, store_symb, _)
    end

    splitted[:body] = new_body
    # Before global espace, splitted[:name] was escaped
    # splitted[:name] = esc(splitted[:name])
    new_func = combinedef(splitted)
    return esc(quote
        $(struct_def)
        $(new_func)
    end)
end

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
            for _ in 1:($(n_iterations)- 1)
                $(body)
            end
        end
    end

    state_symb = gensym()
    
    global node_counter
    node_counter += 1
    id = node_counter

    reset_symb = gensym()

    map!(esc, args, args)
    for arg in [reset_symb, id, state_symb]
        insert!(args, 1, arg)
    end

    func_call = quote $(esc(f))($(args...)) end
    loop_code = loop_creator(func_call)

    code = quote
        $(state_symb) = State(Vector{Any}(undef, $(node_counter)))
        $(reset_symb) = true
        $(func_call)
        $(reset_symb) = false
        $(loop_code)
    end
    return code
end
