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
