function dist(node::Initialized)
    @assert has_parent(node)
    parent = get_parent(node)
    parent_dist = dist(parent)
    cond_dist = condition_cd(parent_dist, node.cd)
    node_dist = node.cd(parent_dist)
    return node_dist
end

function dist(node::Union{Marginalized,Realized})
    node.d
end

function dist!(node::Initialized)
    @assert has_parent(node)
    parent = get_parent(node)
    parent_dist = dist!(parent)
    cond_dist = condition_cd(parent_dist, node.cd)
    if !(parent isa Realized)
        new_node = Initialized(id(parent), id(node), cond_dist)
    end
    node_dist = node.cd(parent_dist)
    return node_dist
end

function realize!(node::Initialized, value::Union{Number,AbstractArray})
    @assert has_parent(node)
    parent = get_parent(node)
    parent_dist = dist!(parent)
    return node.cd(parent_dist), condition(parent_dist, node.cd, value)
end

function dist!(node::Union{Marginalized,Realized})
    node.d
end

observe!(::Realized, ::AbstractArray) = throw(RealizedObservation())

function observe!(node::Marginalized, value::Union{Number,AbstractArray})
    new_node = Realized(id(node), value)
    return logpdf(node.d, value)
end

function observe!(node::Initialized, value::Union{Number,AbstractArray})
    @assert has_parent(node)
    parent = get_parent(node)
    node_dist, new_dist_parent = realize!(node, value)
    ll = logpdf(node_dist, value)
    new_node = Marginalized(id(parent), new_dist_parent)
    realized_node = Realized(id(node), value)
    return ll
end

function sample!(node::Marginalized)
    val = rand(node.d)
    return observe!(node, val), val
end

function value!(node::Realized)
    return node, node.val
end

function value!(node::Marginalized)
    _, val = sample!(node)
    return node, val
end

function value!(node::Initialized)
    node_dist = dist!(node)
    val = rand(node_dist)
    new_node = Realized(id(node), val)
    return new_node, val
end

function rand!(node::Initialized)
    node_dist = dist!(node)
    val = rand(node_dist)
    new_node = Marginalized(id(node), node_dist)
    return new_node, val
end

rand!(node::Marginalized) = (node, rand(node.d))
rand!(node::Realized) = (node, node.val)

# Exposed interface
function initialize!(::GraphicalModel, d::Distribution)
    node = Marginalized(d)
    @debug "Initialize $node"
    return id(node)
end

function initialize!(::GraphicalModel, cd::ConditionalDistribution, parent_id)
    node = Initialized(parent_id, cd)
    @debug "Initialize $node"
    return id(node)
end

function value!(::GraphicalModel, id)
    @debug "Value $(get_node(id))"
    _, val = value!(get_node(id))
end

function rand!(::GraphicalModel, id)
    _, val = rand!(get_node(id))
    @debug "Rand $(get_node(id)) with value $val"
    return val
end

function observe!(::GraphicalModel, id, value::Union{Number,AbstractArray})
    @debug "Observe $(get_node(id)) with value $value"
    ll = observe!(get_node(id), value)
    return ll
end

function dist!(::GraphicalModel, id)
    @debug "Dist $(get_node(id))"
    d = dist!(get_node(id))
    return d
end

function dist(::GraphicalModel, id)
    @debug "Dist $(get_node(id))"
    d = dist(get_node(id))
    return d
end
