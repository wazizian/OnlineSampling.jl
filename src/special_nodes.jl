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
    Pre-defined node which replace [@observe](@ref) calls
    Calls [internal_observe](@ref)
"""
@node function observe(var, obs)
    current_obs = @node iterate(obs)
    return internal_observe(var, current_obs)
end

"""
    Pre-defined node which executes a SMC
"""
@node function smc(
    nparticles::Int64,
    storetype::T,
    step!::F,
    args...,
) where {T<:DataType,F<:Function}
    # TODO (impr): get the return type if avaiblable ?
    @init void_cloud = Cloud{Particle{storetype}}(nparticles)
    @init cloud = smc_node_step(step!, void_cloud, true, args...)
    cloud = smc_node_step(step!, (@prev cloud), false, args...)
    return cloud
end
