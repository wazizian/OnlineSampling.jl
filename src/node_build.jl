"""
   Remove [@observe](@ref) calls during replays
"""
function remove_observe_calls(body::Expr)
    return postwalk(body) do ex
        @capture(ex, (@observe var_ val_) | (@observe(var_, val_))) || return ex
        return quote end
    end
end

"""
    Global reference to the shadow function `internal_update_loglikelihood`
"""
const loglikelihoodCall = :($(Symbol(@__MODULE__)).internal_update_loglikelihood)

"""
    Replace [@observe](@ref) statements with calls to [internal_observe](@ref)
    Note that it must be called before the pass on nodes.
"""
function treat_observe_calls(body::Expr)
    @gensym ll
    return postwalk(body) do ex
        @capture(ex, (@observe var_ val_) | (@observe(var_, val_))) || return ex
        return quote
            $ll = $(@__MODULE__).internal_observe($var, $val)
            $(loglikelihoodCall)($ll)
        end
    end
end

"""
    Replace `internal_update_loglikelihood` with an actual loglikelihood update
"""
function treat_loglikelihood_updates(llsymb::Symbol, body::Expr)
    return postwalk(body) do ex
        isexpr(ex, :call) && ex.args[1] == loglikelihoodCall || return ex
        return quote
            $(llsymb) += $(ex.args[2])
        end
    end
end

"""
    Replace calls to rand with [internal_rand](@ref) and collect variable names
"""
function treat_rand_calls(ctx_symb::Symbol, store_rand::Bool, replay_rand::Bool, body::Expr)
    return postwalk(body) do ex
        @capture(ex, rand(d_)) || return ex
        @gensym rand_var_symb
        rand_code = quote
            $rand_var_symb = $(@__MODULE__).internal_rand($ctx_symb, $d)
        end
        if store_rand
            store_rand_code = quote
                $(@__MODULE__).store_rand_var!(
                    $ctx_symb,
                    $(QuoteNode(rand_var_symb)),
                    $rand_var_symb,
                )
                $rand_var_symb
            end
            return push_front(rand_code, store_rand_code)
        elseif replay_rand
            @gensym replay_rand_var
            replay_rand_code = quote
                $replay_rand_var = $(@__MODULE__).get_stored_rand_var(
                    $ctx_symb,
                    $(QuoteNode(rand_var_symb)),
                )
                @observe($rand_var_symb, $replay_rand_var)
                $replay_rand_var
            end
            return push_front(rand_code, replay_rand_code)
        else
            return rand_code
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
                walked_val = walk(val)
                return (reset ?
                        # if reset, the value of var = val is actually the init value of var
                        quote
                    begin
                        $(var)
                    end
                end : quote
                    $(var) = $(walked_val)
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

"""
    Build a call to the SMC as a node call
"""
function build_smc_call(
    toplevel,
    marg,
    node_particles,
    algo,
    f,
    resample_threshold,
    args...;
)
    macrosymb = toplevel ? Symbol("@nodeiter") : Symbol("@nodecall")
    wrap_func = toplevel ? :($(@__MODULE__).cst) : :(identity)
    symbval = :($(@__MODULE__).choose_ctx_type($algo))
    return Expr(
        :macrocall,
        macrosymb,
        @__LOCATION__,
        marg,
        quote
            # TODO (feat): use expectation over cloud as likelihood
            # For this, add a method to OnlineSMC.likelihood for the store of smc (whose type is det)
            # TODO (impr): the context used at toplevel and inside SMCs are disjoint
            # how can we remedy this ?
            $(@__MODULE__).smc(
                $(wrap_func)($(node_particles)),
                $(wrap_func)($(symbval)),
                $(wrap_func)($(f)),
                $(wrap_func)($(resample_threshold)),
                $(args...),
            )
        end,
    )
end

"""
    Handle `@nodecall` calls.
    Must be called before the init, stored variables and loglikelihood passes
"""
function treat_node_calls(ctxsymb::Symbol, body::Expr)
    return prewalk(body) do ex
        @capture(ex, @nodecall margs__ f_(args__)) || return ex
        node_particles = :(0)
        reset_cond = :(false)
        algo = :(particle_filter)
        resample_threshold = :(0.5)
        for marg in margs
            if @capture(marg, particles = val_)
                node_particles = val
            elseif @capture(marg, algo = val_)
                algo = val
            elseif @capture(marg, rt = val_)
                resample_threshold = val
            else
                reset_cond = marg
            end
        end

        if node_particles != :(0)
            smc_call = build_smc_call(
                false,
                reset_cond,
                node_particles,
                algo,
                f,
                resample_threshold,
                args...,
            )
            return quote
                begin
                    # The fact that we used prewalk and inserted a begin...end block here
                    # guarantees that this node_call will be treated at the next iteration
                    $(smc_call)
                end
            end
        end

        tmp = gensym()
        @gensym next state ll ret
        return quote
            @init $(next) = $(f)(:(nothing), true, $(ctxsymb), $(args...))
            $(next) = $(f)(@prev($(state)), $(reset_cond), $(ctxsymb), $(args...))
            # TODO: handle tuples on LHS and remove this line
            $(state) = $(next)[1]
            $(ll) = $(next)[2]
            $(ret) = $(next)[3]
            $(loglikelihoodCall)($(ll))
            $(ret)
        end
    end
end

"""
    Collect variables which appear inside `@prev` calls
"""
function collect_stored_variables(store_symb::Symbol, reset_symb::Symbol, body::Expr)
    stored_vars = Set{Symbol}()
    postwalk(body) do ex
        @capture(ex, (@prev e_) | (@prev(e_))) || return ex
        isexpr(e, Symbol) ||
            error("Ill-formed @prev: got $(ex) but prev only supports variables")
        push!(stored_vars, e)
        return quote
            $(reset_symb) ? $(@__MODULE__).notinit : $(store_symb).$(e)
        end
    end
    return stored_vars, body
end

"""
    Replace `@prev(x)` statements with calls to the store
"""
function fetch_stored_variables(store_symb::Symbol, reset::Bool, body::Expr)
    new_body = postwalk(body) do ex
        @capture(ex, (@prev e_) | (@prev(e_))) || return ex
        return reset ? quote
            $(@__MODULE__).notinit
        end : quote
            $(store_symb).$(e)
        end
    end
    # make sure there are no prev left
    prewalk(new_body) do ex
        @capture(ex, @prev _) && error("Ill formed @prev call inside node: found $(ex)")
    end
    return new_body
end

"""
    Build the stored variable struct
"""
function gather_stored_variables(stored_vars::Set{Symbol})
    stored_vars = collect(stored_vars)
    quoted_vars = map(var -> QuoteNode(var), stored_vars)
    return :(NamedTuple{($(quoted_vars...),)}(($(stored_vars...),)))
end

"""
    Augment returns with stored variables and loglikelihood
"""
function augment_returns(stored_vars::Set{Symbol}, llsymb::Symbol, body::Expr)
    stored_variables_ret = gather_stored_variables(stored_vars)
    @gensym retval
    new_body = postwalk(body) do ex
        @capture(ex, return ret_) || return ex
        return quote
            $(retval) = $(ret)
            return $(@__MODULE__).@protect ($(stored_variables_ret), $(llsymb), $(retval))
        end
    end
    @gensym ret
    return quote
        $(ret) = $(new_body)
        return $(@__MODULE__).@protect ($(stored_variables_ret), $(llsymb), $(ret))
    end
end

"""
    Dummy calls, to mark nodes for the later IR pass
"""
node_marker() = nothing
node_no_reset_marker() = nothing
node_reset_marker() = nothing

function common_body(ctx_symb::Symbol, ll_symb::Symbol, body::Expr)
    init_ll = :($(ll_symb)::Float64 = 0.0)
    return @chain body begin
        push_front(init_ll, _)
        treat_node_calls(ctx_symb, _)
    end
end

function make_body(
    state_symb::Symbol,
    ctx_symb::Symbol,
    ll_symb::Symbol,
    inner_reset_symb::Symbol,
    reset::Bool,
    store_rand::Bool,
    replay_rand::Bool,
    body::Expr,
)
    @assert !reset || (!store_rand && !replay_rand)
    @assert !store_rand || !replay_rand

    marker =
        reset ? :($(@__MODULE__).node_reset_marker()) :
        :($(@__MODULE__).node_no_reset_marker())

    return @chain body begin
        replay_rand ? remove_observe_calls(_) : _
        treat_rand_calls(ctx_symb, store_rand, replay_rand, _)
        treat_observe_calls
        treat_loglikelihood_updates(ll_symb, _)
        stored_vars, _ = collect_stored_variables(state_symb, inner_reset_symb, _)
        fetch_stored_variables(state_symb, reset, _[2])
        augment_returns(stored_vars, ll_symb, _)
        treat_initialized_vars(reset, _)
        push_front(:($(inner_reset_symb) = $reset), _)
        push_front(marker, _)
        # @aside sh(_)
    end
end

function node_build(splitted)
    node_name = splitted[:name]
    body = splitted[:body]

    rtype = get(splitted, :type, :Any)
    new_rtype = :(Tuple{NamedTuple,Float64,$(rtype)})
    splitted[:rtype] = new_rtype

    @gensym state_symb

    # sampling context, as defined in tracked_rv.jl
    @gensym ctx_symb

    # loglikelihood
    @gensym ll_symb

    # reset var
    @gensym inner_reset_symb

    new_body = common_body(ctx_symb, ll_symb, body)

    no_reset_body = make_body(
        state_symb,
        ctx_symb,
        ll_symb,
        inner_reset_symb,
        false,
        false,
        false,
        new_body,
    )
    store_rand_body = make_body(
        state_symb,
        ctx_symb,
        ll_symb,
        inner_reset_symb,
        false,
        true,
        false,
        new_body,
    )
    replay_rand_body = make_body(
        state_symb,
        ctx_symb,
        ll_symb,
        inner_reset_symb,
        false,
        false,
        true,
        new_body,
    )
    reset_body = make_body(
        state_symb,
        ctx_symb,
        ll_symb,
        inner_reset_symb,
        true,
        false,
        false,
        new_body,
    )

    # Create inner functions
    name = splitted[:name]
    insert!(splitted[:args], 1, :($(ctx_symb)::$(@__MODULE__).SamplingCtx))

    @gensym no_reset_inner_name store_rand_inner_name replay_rand_inner_name reset_inner_name

    # Create reset function
    splitted[:body] = reset_body
    splitted[:name] = reset_inner_name
    reset_inner_func = combinedef(splitted)

    # Create no_reset function
    splitted[:body] = no_reset_body
    splitted[:name] = no_reset_inner_name
    insert!(splitted[:args], 1, :($(state_symb)))
    no_reset_inner_func = combinedef(splitted)

    # Create store_rand function
    splitted[:body] = store_rand_body
    splitted[:name] = store_rand_inner_name
    store_rand_inner_func = combinedef(splitted)

    # Create replay_rand function
    splitted[:body] = replay_rand_body
    splitted[:name] = replay_rand_inner_name
    replay_rand_inner_func = combinedef(splitted)

    # Create inner function calls
    # Remove type annotation in arg
    splitted[:args][1] = :($(state_symb))
    splitted[:args][2] = ctx_symb

    @gensym tmp outer_reset_symb
    inner_func_call = quote
        $(tmp) = if $(outer_reset_symb)
            $(@__MODULE__).irpass(
                $(reset_inner_name),
                $(splitted[:args][2:end]...);
                $(splitted[:kwargs]...),
            )
        elseif !$(@__MODULE__).is_jointPF($ctx_symb)
            $(@__MODULE__).irpass(
                $(no_reset_inner_name),
                $(splitted[:args]...);
                $(splitted[:kwargs]...),
            )
        elseif $(@__MODULE__).is_jointPF_store($ctx_symb)
            $(@__MODULE__).irpass(
                $(store_rand_inner_name),
                $(splitted[:args]...);
                $(splitted[:kwargs]...),
            )
        else
            $(@__MODULE__).irpass(
                $(replay_rand_inner_name),
                $(splitted[:args]...);
                $(splitted[:kwargs]...),
            )
        end
    end

    # Create wrapper func
    outer_body = quote
        # mark as node for later passes
        $(@__MODULE__).node_marker()
        $(inner_func_call)
        $(tmp)
    end
    splitted[:body] = outer_body
    splitted[:name] = name
    splitted[:args][2] = :($(ctx_symb)::$(@__MODULE__).SamplingCtx)
    insert!(splitted[:args], 2, :($(outer_reset_symb)::Bool))
    outer_func = combinedef(splitted)

    code = esc(quote
        $(no_reset_inner_func)
        $(store_rand_inner_func)
        $(replay_rand_inner_func)
        $(reset_inner_func)
        # Redirect documentation of @node definitions
        Core.@__doc__($(outer_func))
    end)
    # sh(code)
    # shh(code)
    return code
end
