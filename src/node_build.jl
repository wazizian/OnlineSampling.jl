"""
    Replace [@observe](@ref) statements with calls to [internal_observe](@ref)
    Note that it must be called before the pass on nodes.
"""
function treat_observe_calls(body::Expr)
    return postwalk(body) do ex
        @capture(ex, (@observe var_ val_) | (@observe(var_, val_))) || return ex
        return quote
            @nodecall $(@__MODULE__).observe($(var), $(val))
        end
    end
end

"""
    Global reference to the shadow function `internal_update_loglikelihood`
"""
const loglikelihoodCall = :($(Symbol(@__MODULE__)).internal_update_loglikelihood)

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
function build_smc_call(macrosymb, marg, node_particles, dsval, bpval, f, args...)
    (dsval != :(false)) &&
        (bpval != :(false)) &&
        error("DS and BP symbolic inference cannot be both enabled")
    symbval = if dsval != :(false)
        :($(dsval) ? $(@__MODULE__).DSOnCtx : $(@__MODULE__).OffCtx)
    else
        :($(bpval) ? $(@__MODULE__).BPOnCtx : $(@__MODULE__).OffCtx)
    end
    return Expr(:macrocall, macrosymb, quote
        # TODO (feat): use expectation over cloud as likelihood
        # For this, add a method to OnlineSMC.likelihood for the store of smc (whose type is det)
        # TODO (impr): the context used at toplevel and inside SMCs are disjoint
        # how can we remedy this ?
        $(marg) $(@__MODULE__).smc(
            $(node_particles),
            $(symbval),
            $(f),
            $(args...),
        )
    end
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
        reset_cond = dsval = bpval = :(false)
        for marg in margs
            if @capture(marg, particles = val_)
                node_particles = val
            elseif @capture(marg, DS = val_)
                dsval = val
            elseif @capture(marg, BP = val_)
                bpval = val
            else
                reset_cond = marg
            end
        end

        if node_particles != :(0)
            smc_call = build_smc_call(Symbol("@nodecall"), reset_cond, node_particles, dsval, bpval, f, args...)
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
    init_ll = :($(ll_symb)::Float64 = 0.0)

    # common pass
    @gensym inner_reset_symb
    stored_vars, new_body = @chain body begin
        push_front(init_ll, _)
        treat_observe_calls
        treat_rand_calls(ctx_symb, _)
        treat_node_calls(ctx_symb, _)
        treat_loglikelihood_updates(ll_symb, _)
        collect_stored_variables(state_symb, inner_reset_symb, _)
    end

    # not reset pass
    no_reset_body = @chain new_body begin
        fetch_stored_variables(state_symb, false, _)
        augment_returns(stored_vars, ll_symb, _)
        treat_initialized_vars(false, _)
        push_front(:($(inner_reset_symb) = false), _)
        push_front(:($(@__MODULE__).node_no_reset_marker()), _)
    end

    # reset pass
    reset_body = @chain new_body begin
        fetch_stored_variables(state_symb, true, _)
        augment_returns(stored_vars, ll_symb, _)
        treat_initialized_vars(true, _)
        push_front(:($(inner_reset_symb) = true), _)
        push_front(:($(@__MODULE__).node_reset_marker()), _)
    end

    # Create inner functions
    name = splitted[:name]
    insert!(splitted[:args], 1, :($(ctx_symb)::$(@__MODULE__).SamplingCtx))

    @gensym no_reset_inner_name reset_inner_name

    # Create reset function
    splitted[:body] = reset_body
    splitted[:name] = reset_inner_name
    reset_inner_func = combinedef(splitted)

    # Create no_reset function
    splitted[:body] = no_reset_body
    splitted[:name] = no_reset_inner_name
    insert!(splitted[:args], 1, :($(state_symb)))
    no_reset_inner_func = combinedef(splitted)

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
        else
            $(@__MODULE__).irpass(
                $(no_reset_inner_name),
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
        $(reset_inner_func)
        # Redirect documentation of @node definitions
        Core.@__doc__($(outer_func))
    end)
    # sh(code)
    # shh(code)
    return code
end
