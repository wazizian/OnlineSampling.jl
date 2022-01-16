"""
    Replace [@observe](@ref) statements with calls to [internal_observe](@ref)
    Note that it must be called before the pass on nodes.
"""
function treat_observe_calls(state_symb::Symbol, body::Expr)
    return postwalk(body) do ex
        @capture(ex, (@observe var_ val_) | (@observe(var_, val_))) || return ex
        return quote
            $(state_symb).loglikelihood += @node $(@__MODULE__).observe($(var), $(val))
        end
    end
end

"""
    Replace calls to rand with [internal_rand](@ref)
"""
function treat_rand_calls(ctx_symb::Symbol, body::Expr)
    return postwalk(body) do ex
        @capture(ex, rand(d_)) || return ex
        return quote
            $(@__MODULE__).internal_rand($(ctx_symb), $(d))
        end
    end
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
                return quote
                    @init $(walk(var)) = $(walk(val))
                end
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
                    end : quote
                        $(walked_var) = $(walked_val)
                    end)
            else
                return nothing
            end
        end
        # init
        postwalk(_) do ex
            @capture(ex, @init var_ = val_) || return ex
            return (reset ? quote
                $(var) = $(val)
                # init statements are not executed anymore outside resets
            end : :(nothing))
        end
    end

    # make sure there are no init left
    postwalk(new_body) do ex
        @capture(ex, @init _) && error("Ill formed @init: found $(ex)")
    end

    return new_body
end

function treat_node_calls(
    state_symb::Symbol,
    reset_symb::Symbol,
    ctx_symb::Symbol,
    body::Expr,
)
    # the dict below maps unique call symbols to struct types
    node_calls = Dict{Symbol,Union{Expr,Symbol}}()
    new_body = prewalk(body) do ex
        @capture(
            ex,
            # TODO (impr): improve below
            (@node cond_ particles = val_ DS = dsval_ f_(args__)) |
            (@node particles = val_ DS = dsval_ f_(args__)) |
            (@node cond_ particles = val_ f_(args__)) |
            (@node particles = val_ f_(args__)) |
            (@node cond_ f_(args__)) |
            (@node f_(args__))
        ) || return ex

        cond = isnothing(cond) ? :(false) : cond
        dsval = isnothing(dsval) ? :(false) : dsval

        # detect smc and compute particles
        node_particles = 0
        if !isnothing(val)
            try
                node_particles = eval(val)::Integer
            catch
                error("Particle number $(val) should be an integer constant")
            end
        end

        mem_struct_type = get_node_mem_struct_type(f)

        if node_particles > 0
            return quote
                # TODO (feat): use expectation over cloud as likelihood
                # For this, add a method to OnlineSMC.likelihood for the store of smc (whose type is det)
                # TODO (impr): the context used at toplevel and inside SMCs are disjoint
                # how can we remedy this ?
                begin
                    # The fact that we used prewalk and inserted a begin...end block here
                    # guarantees that this node_call will be treated at the next iteration
                    @node $(cond) $(@__MODULE__).smc(
                        $(node_particles),
                        $(mem_struct_type),
                        $(dsval) ? $(@__MODULE__).DSOnCtx : $(@__MODULE__).DSOffCtx,
                        $(f),
                        $(args...),
                    )
                end
            end
        end
        # get new id
        call_id = gensym()
        node_calls[call_id] = mem_struct_type

        # integrate reset condition
        reset_cond = :($(reset_symb) || $(cond))
        for arg in [ctx_symb, reset_cond, :($(state_symb).$(call_id))]
            insert!(args, 1, arg)
        end

        # update the score of the current node
        update_score = quote
            $(state_symb).loglikelihood +=
                $(@__MODULE__).OnlineSMC.loglikelihood($(state_symb).$(call_id))
        end

        tmp = gensym()
        return quote
            $(tmp) = $(f)($(args...))
            $(update_score)
            $(tmp)
        end
    end

    # make sure there are no init left
    prewalk(new_body) do ex
        @capture(ex, @node) && error("Ill formed @node call inside node: found $(ex)")
    end

    return node_calls, new_body
end

function collect_stored_variables(store_symb::Symbol, body::Expr)
    # Collect stored variables, normalize & insert call to store
    stored_vars = Set{Symbol}()
    new_body = postwalk(body) do ex
        @capture(ex, (@prev e_) | (@prev(e_))) || return ex
        isexpr(e, Symbol) ||
            error("Ill-formed @prev: got $(ex) but prev only supports variables")
        push!(stored_vars, e)
        return quote
            $(store_symb).$(e)
        end
    end
    # make sure there are no prev left
    prewalk(new_body) do ex
        @capture(ex, @prev _) && error("Ill formed @prev call inside node: found $(ex)")
    end
    return stored_vars, new_body
end

function store_stored_variables(
    state_symb::Symbol,
    store_symb::Symbol,
    stored_vars::Set{Symbol},
    body::Expr,
)
    # store the values for the next time step
    return postwalk(body) do ex
        (@capture(ex, var_ = val_) && var in stored_vars) || return ex
        set_expr = quote
            $(@__MODULE__).setproperties($(state_symb).store, $(var) = $(var))
        end
        return quote
            begin
                $(var) = $(val)
                $(state_symb).store = $(set_expr)
                $(var)
            end
        end
    end
end

function create_structs(
    node_name::Symbol,
    state_symb::Symbol,
    stored_vars::Set{Symbol},
    node_calls::Dict{Symbol,Union{Expr,Symbol}},
)
    # TODO (impr) use type info

    # Build the struct for the current node
    # (to be inserted before func)
    # It is a mutable struct, whose name is deterministic
    # and given by get_node_mem_struct_type(node_name), and which contains,
    # 1. An immutable struct which stores the variables which appear in prev
    # 2. The mutable structs of the nodes called inside
    # 3. The loglikelihood

    # First, we build the structure for the stored variables
    @gensym store_struct_symb
    init_stored_vars = map(_ -> notinit, 1:length(stored_vars))
    store_struct_def = quote
        struct $(store_struct_symb)
            $(stored_vars...)
        end
    end
    # add the constructor only if stored_vars != emptyset
    full_store_struct_def =
        isempty(stored_vars) ? store_struct_def :
        quote
            $(store_struct_def)
            # constructor
            $(store_struct_symb)() = $(store_struct_symb)($(init_stored_vars...))
        end

    # Then, we build the full structure for the node
    mem_struct_symb = get_node_mem_struct_type(node_name)
    node_call_fields = [:($(id)::$(type)) for (id, type) in node_calls]
    node_call_inits = [:($(type)()) for type in values(node_calls)]
    mem_struct_def = quote
        mutable struct $(mem_struct_symb)
            loglikelihood::Float64
            store::$(store_struct_symb)
            $(node_call_fields...)
        end
        # constructor
        $(mem_struct_symb)() =
            $(mem_struct_symb)(0.0, $(store_struct_symb)(), $(node_call_inits...))
    end

    struct_defs = quote
        $(full_store_struct_def)
        $(mem_struct_def)
    end

    # copy code to be called after the end of func
    # make sure it uses our version of deepcopy, and not the one of our user
    copy_code = @chain quote
        $(state_symb).store
    end begin
        quote
            $(@__MODULE__).deepcopy($(_))
        end
        quote
            $(state_symb).store = $(_)
        end
    end

    # Build reset code
    node_call_resets = [:($(state_symb).$(id) = $(type)()) for (id, type) in node_calls]
    reset_code = quote
        $(state_symb).store = $(store_struct_symb)()
        $(node_call_resets...)
    end

    return mem_struct_symb, struct_defs, copy_code, reset_code
end

"""
    Dummy calls, to mark nodes for the later IR pass
"""
node_marker() = nothing
node_no_reset_marker() = nothing
node_reset_marker() = nothing

function node_build(splitted)
    node_name = splitted[:name]
    body = splitted[:body]

    state_symb = gensym()
    store_symb = gensym()
    assign_store = quote
        $(store_symb) = $(state_symb).store
    end

    # sampling context, as defined in tracked_rv.jl
    ctx_symb = gensym()

    # common pass
    inner_reset_symb = gensym()
    stored_vars, (node_calls, new_body) = @chain body begin
        push_front(assign_store, _)
        treat_observe_calls(state_symb, _)
        treat_rand_calls(ctx_symb, _)
        collect_stored_variables(store_symb, _)
        _[1], treat_node_calls(state_symb, inner_reset_symb, ctx_symb, _[2])
    end

    # create structs
    struct_symb, structs_def, copy_code, reset_code =
        create_structs(node_name, state_symb, stored_vars, node_calls)

    # not reset pass
    no_reset_body = @chain new_body begin
        treat_initialized_vars(false, _)
        store_stored_variables(state_symb, store_symb, stored_vars, _)
        push_front(:($(inner_reset_symb) = false), _)
        push_front(:($(@__MODULE__).node_no_reset_marker()), _)
    end

    # reset pass
    reset_body = @chain new_body begin
        treat_initialized_vars(true, _)
        push_front(reset_code, _)
        store_stored_variables(state_symb, store_symb, stored_vars, _)
        push_front(:($(inner_reset_symb) = true), _)
        push_front(:($(@__MODULE__).node_reset_marker()), _)
    end

    # Create inner functions
    name = splitted[:name]
    insert!(splitted[:args], 1, :($(state_symb)::$(struct_symb)))
    insert!(splitted[:args], 2, :($(ctx_symb)::$(@__MODULE__).SamplingCtx))

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
    # Remove type annotation in arg
    splitted[:args][1] = :($(state_symb))
    splitted[:args][2] = ctx_symb

    tmp = gensym()
    outer_reset_symb = gensym()
    inner_func_call = quote
        $(tmp) = if $(outer_reset_symb)
            $(reset_inner_name)($(splitted[:args]...); $(splitted[:kwargs]...))
        else
            $(no_reset_inner_name)($(splitted[:args]...); $(splitted[:kwargs]...))
        end
    end

    # Reset score
    reinit_score = quote
        $(state_symb).loglikelihood = 0.0
    end

    # Create wrapper func
    outer_body = quote
        # mark as node for later passes
        $(@__MODULE__).node_marker()
        $(reinit_score)
        $(inner_func_call)
        $(copy_code)
        $(tmp)
    end
    splitted[:body] = outer_body
    splitted[:name] = name
    splitted[:args][1] = :($(state_symb)::$(struct_symb))
    splitted[:args][2] = :($(ctx_symb)::$(@__MODULE__).SamplingCtx)
    insert!(splitted[:args], 2, :($(outer_reset_symb)::Bool))
    outer_func = combinedef(splitted)

    code = esc(quote
        $(structs_def)
        $(no_reset_inner_func)
        $(reset_inner_func)
        # Redirect documentation of @node definitions
        Core.@__doc__($(outer_func))
    end)
    # sh(code)
    # println(postwalk(rmlines, code))
    return code
end
