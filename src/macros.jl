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
# Ignore x if not an expr
stopwalk(f, x) = x

const unesc = Symbol("hygienic-scope")

function unescape(transf, expr_args...)
    # unescape the code transformation transf
    return @chain expr_args begin
        map(esc, _)
        transf(_...)
        Expr(unesc, _, @__MODULE__)
    end
end

# Propagation of nothing
Cassette.@context NothingCtx

nothing_overdub(f, args...) = Cassette.overdub(Cassette.disablehooks(NothingCtx()), f, args...)

function Cassette.overdub(ctx::NothingCtx, f, args...)
    if !applicable(f, args...)
        return nothing
    elseif Cassette.canrecurse(ctx, f, args...)
        return Cassette.recurse(ctx, f, args...)
    else
        return Cassette.fallback(ctx, f, args...)
    end
end

function Cassette.overdub(ctx::NothingCtx, ::typeof(nothing_overdub), args...)
    return Cassette.overdub(ctx, args[1], args[2:end]...)
end

function treat_initialized_vars(reset::Bool, body::Expr)::Expr
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
            if @capture(ex, @init var_ = val_) 
                return quote @init $(walk(var)) = $(walk(val)) end
            elseif @capture(ex, var_ = val_) && var in initialized_vars 
                walked_var = walk(var)
                walked_val = walk(val)
                return (reset ?
                        # if reset, the value of var = val is actually the init value of var
                        quote 
                            begin 
                                $(walked_val)
                                $(walked_var)
                            end
                        end 
                        : quote $(walked_var) = $(walked_val) end)
            else
                return nothing
            end
        end
        # init
        postwalk(_) do ex
            @capture(ex, @init var_ = val_) || return ex
            return (reset ? quote $(var) = $(val) end : val)
        end
    end

    # make sure there are no init left
    postwalk(new_body) do ex
        @capture(ex, @init _) && error("Ill formed @init: found $(ex)")
    end

    return new_body
end

function treat_node_calls(state_symb::Symbol, reset::Bool, body::Expr)::Expr
    new_body = postwalk(body) do ex
        @capture(ex, (@node cond_ f_(args__)) | (@node f_(args__))) || return ex

        # get new id
        global node_counter
        node_counter += 1
        id = node_counter

        # integrate reset condition
        reset_cond = isnothing(cond) ? :($(reset)) : :($(reset) || $(cond))
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

function treat_stored_variables(state_symb::Symbol, func_id_symb::Symbol, store_symb::Symbol, body::Expr)
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
            set_expr = quote
                $(@__MODULE__).setproperties($(store_symb), $(var) =  $(var))
            end
            return quote
                begin
                    $(var) = $(val)
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

    return stored_vars, new_body
end

function create_struct(state_symb::Symbol, func_id_symb::Symbol, stored_vars::Set{Symbol})
    # TODO (impr) use type info
    # Build stored struct
    # (to be inserted before func)
    struct_symb = gensym()
    # TODO (bug) use the line below and propagate nothings with cassette 
    init_stored_vars = map(_ -> nothing, 1:length(stored_vars))
    # init_stored_vars = zeros(Int64, length(stored_vars))
    struct_def = quote
        # I don't know why by $(struct_symb) is already escaped below
        struct $(struct_symb)
            $(stored_vars...)
        end
    end
    # add the constructor only if stored_vars != emptyset
    full_struct_def = isempty(stored_vars) ? struct_def : quote
        $(struct_def)
        # constructor
        $(struct_symb)() = $(struct_symb)($(init_stored_vars...))
    end

    # copy code to be called after the end of func
    # make sure it uses our version of deepcopy, and not the one of our user
    copy_code = @chain quote $(state_symb).nodestates[$(func_id_symb)] end begin
        quote $(@__MODULE__).deepcopy($(_)) end
        quote $(state_symb).nodestates[$(func_id_symb)] = $(_) end
    end

    # Build reset code
    reset_code = quote ($(state_symb).nodestates[$(func_id_symb)] = $(struct_symb)()) end

    return full_struct_def, copy_code, reset_code
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
    for symb in [func_id_symb, state_symb]
        insert!(splitted[:args], 1, symb)
    end

    body = splitted[:body]

    store_symb = gensym()
    assign_store = quote
        $(store_symb) = $(state_symb).nodestates[$(func_id_symb)]
    end

    global node_counter
    backup_node_coutner = node_counter

    stored_vars, no_reset_body = @chain body begin
        push_front(assign_store, _)
        treat_initialized_vars(false, _)
        treat_node_calls(state_symb, false, _)
        treat_stored_variables(state_symb, func_id_symb, store_symb, _)
    end

    node_counter = backup_node_coutner

    struct_def, copy_code, reset_code = create_struct(state_symb, func_id_symb, stored_vars)

    _, reset_body = @chain body begin
        push_front(assign_store, _)
        treat_initialized_vars(true, _)
        treat_node_calls(state_symb, true, _)
        push_front(reset_code, _)
        treat_stored_variables(state_symb, func_id_symb, store_symb, _)
    end

    # Create inner functions
    name = splitted[:name]

    no_reset_inner_name = gensym()
    reset_inner_name = gensym()

    # Create no_reset function
    splitted[:body] = no_reset_body
    splitted[:name] = no_reset_inner_name
    no_reset_inner_func = combinedef(splitted)

    # Create reset function
    splitted[:body] = reset_body
    splitted[:name] = reset_inner_name
    reset_inner_func = combinedef(splitted)

    # Create inner function calls
    # TODO (issue) : keywords not supported for now
    reset_func_call = quote
        $(@__MODULE__).nothing_overdub($(reset_inner_name), $(splitted[:args]...))
    end

    tmp = gensym()
    inner_func_call = quote
        $(tmp) = 
        if $(reset_symb)
            $(reset_func_call)
            #$(reset_inner_name)($(splitted[:args]...); $(splitted[:kwargs]...))
        else
            $(no_reset_inner_name)($(splitted[:args]...); $(splitted[:kwargs]...))
        end
    end

    # Create wrapper func
    outer_body = quote
        $(inner_func_call)
        $(copy_code)
        $(tmp)
    end
    insert!(splitted[:args], 3, reset_symb)
    splitted[:body] = outer_body
    splitted[:name] = name
    outer_func = combinedef(splitted)

    code = esc(quote
        $(struct_def)
        $(no_reset_inner_func)
        $(reset_inner_func)
        $(outer_func)
    end)
    return code
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
