function dist!(gm::GraphicalModel, node::Initialized)
    @assert has_parent(gm, node)
    parent = get_parent(gm, node)
    parent_dist = dist!(gm,parent)
    cond_dist = condition_cd(parent_dist, node.cd)
    if !(parent isa Realized)
        new_node = Initialized(parent.id,node.id,cond_dist)
        set!(gm,new_node)
    end
    node.cd(parent_dist)
end

function dist!(gm::GraphicalModel, node::Initialized, value::AbstractArray)
    @assert has_parent(gm, node)
    parent = get_parent(gm, node)
    parent_dist = dist!(gm,parent)
    return node.cd(parent_dist), condition(parent_dist, node.cd, value)
end

function dist!(gm::GraphicalModel, node::Union{Marginalized,Realized})
    node.d
end

function observe!(gm::GraphicalModel, node::Marginalized, value::AbstractArray)
    new_node = Realized(node.id, value)
    set!(gm, new_node)
    return logpdf(node.d, value)
end


function observe!(gm::GraphicalModel, node::Initialized, value::AbstractArray)
    @assert has_parent(gm, node)
    parent = get_parent(gm, node)
    node_dist, new_dist_parent = dist!(gm, node, value)
    ll = logpdf(node_dist, value)
    new_node = Marginalized(parent.id,new_dist_parent)
    set!(gm,new_node)
    realized_node = Realized(node.id,value)
    set!(gm, realized_node)
    return ll
end

# Exposed interface
function initialize!(gm::GraphicalModel{I}, d::Distribution) where {I}
    id = new_id(gm)
    node = Marginalized(id, d)
    set!(gm, node)
    @debug "Initialize $node"
    return id
end

function initialize!(
    gm::GraphicalModel{I},
    cd::ConditionalDistribution,
    parent_id::I,
) where {I}
    id = new_id(gm)
    #parent = gm.nodes[parent_id]
    #parent_child_ref = push!(parent.children, id)
    node = Initialized(id, parent_id, cd)
    set!(gm, node)
    @debug "Initialize $node"
    return id
end

function observe!(gm::GraphicalModel{I}, id::I, value::AbstractArray) where {I}
    @debug "Observe $(gm.nodes[id]) with value $value"
    ll = observe!(gm, gm.nodes[id], value)
    return ll
end

function sample!(gm::GraphicalModel, node::Marginalized)
    #@assert is_terminal(gm, node)
    val = rand(node.d)
    return observe!(gm, node, val), val
end

function value!(gm::GraphicalModel, node::Realized)
    return node, node.val
end

function value!(gm::GraphicalModel, node::Union{Marginalized,Initialized})
    #@assert has_parent(gm, node)
    #parent = get_parent(gm, node)
    node_dist = dist!(gm, node)
    new_node = Marginalized(node.id,node_dist)
    set!(gm, new_node)
    _, val = sample!(gm, new_node)
    return new_node, val
end
