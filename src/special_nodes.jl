"""
    Pre-defined node which iterates over an iterable
"""
@node function iterate(iter)
    Base.depwarn("The node iterate is deprecated", :iterate, force = true)
    @init next = Base.iterate(iter)
    _, prev_state = @prev next
    next = Base.iterate(iter, prev_state)
    next == nothing && error("Not enough elements in iterable")
    item, _ = next
    return item
end

"""
    Determine how an observation sequence should be iterated
    - If `obs::Vector{T}`, yield elements of type `T`
    - If `obs::Array{T,N}` with `N ≥ 2`, yield slices along the first dimension.
    - Otherwise, iterate over `obs`.
"""
@node function iterate_obs(obs)
    Base.depwarn("The node iterate_obs is deprecated", :iterate_obs, force = true)
    @nodecall _iterate_obs(obs)
end

@node _iterate_obs(obs::AbstractVector) = @nodecall iterate(obs)
@node _iterate_obs(obs::AbstractArray) = @nodecall iterate(eachslice(obs; dims = 1))
@node _iterate_obs(obs) = @nodecall iterate(obs)

"""
    Pre-defined node which replace [@observe](@ref) calls
    Calls [internal_observe](@ref) and [internal_update_loglikelihood](@ref)
"""
@node function observe(var, obs)
    Base.depwarn("The node observe is deprecated", :iterate_obs, force = true)
    ll = internal_observe(var, obs)
    OnlineSampling.internal_update_loglikelihood(ll)
end

"""
    Pre-defined node which executes a SMC
"""
@node function smc(
    nparticles::Int64,
    ctx_type::Type{C},
    step::F,
    resample_threshold::Float64,
    args...,
) where {C<:SamplingCtx,F<:Function}
    # TODO (impr): get the return type if avaiblable ?
    @init void_cloud = SMC.Cloud{MemParticle{Nothing,C,Nothing}}(nparticles)
    @init cloud = smc_node_step(step, void_cloud, true, resample_threshold, args...)
    cloud = smc_node_step(step, (@prev cloud), false, resample_threshold, args...)
    return sanitize_return(cloud)
end
