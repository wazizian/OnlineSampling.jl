"""
    Pre-defined node which iterates over an iterable
"""
@node function iterate(iter)
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
@node iterate_obs(obs::AbstractVector) = @node iterate(obs)
@node iterate_obs(obs::AbstractArray) = @node iterate(eachslice(obs; dims = 1))
@node iterate_obs(obs) = @node iterate(obs)

"""
    Pre-defined node which replace [@observe](@ref) calls
    Calls [internal_observe](@ref)
"""
@node function observe(var, obs)
    current_obs = @node iterate_obs(obs)
    ll = internal_observe(var, current_obs)
    OnlineSampling.internal_update_loglikelihood(ll)
end

"""
    Pre-defined node which executes a SMC
"""
@node function smc(
    nparticles::Int64,
    ctx_type::Type{C},
    step::F,
    args...,
) where {C<:SamplingCtx,F<:Function}
    # TODO (impr): get the return type if avaiblable ?
    @init void_cloud = SMC.Cloud{Particle{Nothing,C,Nothing}}(nparticles)
    @init cloud = smc_node_step(step, void_cloud, true, args...)
    cloud = smc_node_step(step, (@prev cloud), false, args...)
    return unwrap_tracked_value(cloud)
end
