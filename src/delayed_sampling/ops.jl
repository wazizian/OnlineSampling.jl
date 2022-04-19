function realize!(gm::GraphicalModel, node::Marginalized, val::Union{Number,AbstractArray})
    # Does renew node
    @chain node begin
        @aside @assert is_terminal(gm, _)

        @aside rm_marginalized_child!(gm, _)

        Realized(_, val)

        @aside update!(gm, _)

        detach!(gm, _)
        condition!(gm, _)

        @aside update!(gm, _)
    end
end

function detach!(gm::GraphicalModel, node::Realized)
    # Does enew node
    for child_id in node.children
        # Transform of child
        @chain gm.nodes[child_id] begin
            marginalize!(gm, _)
            # Remove edge node -> child
            @set _.parent_id = nothing
            @set _.parent_child_ref = nothing
            update!(gm, _)
        end
    end
    # Remove all children (in O(1))
    empty!(node.children)
    return node
end

function condition!(gm::GraphicalModel, node::Realized)
    # Does renew node
    if !has_parent(gm, node)
        return node
    end

    # Transform of parent
    @chain get_parent(gm, node) begin
        # Marginalize parent
        primitive_marginalize_parent(node, _)
        @aside add_marginalized_child!(gm, _)
        # Delete edge parent -> node 
        @aside deleteat!(_.children, node.parent_child_ref)
        update!(gm, _)
    end

    # Delete edge parent -> node
    @chain node begin
        @set _.parent_id = nothing
        @set _.parent_child_ref = nothing
    end
end

function marginalize!(gm::GraphicalModel, node::Initialized)
    # Does renew node
    @assert has_parent(gm, node)

    parent = get_parent(gm, node)
    @assert parent isa Marginalized || parent isa Realized

    @chain node begin
        primitive_marginalize_child(_, parent)
        # WARNING parent not valied anymore after next line
        @aside add_marginalized_child!(gm, _)
        # Should not be needed
        # update!(gm, _)
    end
end

function sample!(gm::GraphicalModel, node::Marginalized)
    # Does renew node
    @assert is_terminal(gm, node)
    val = rand(node.d)
    return realize!(gm, node, val), val
end

function value!(gm::GraphicalModel, node::Realized)
    # Does renew node
    return node, node.val
end

function value!(gm::GraphicalModel, node::AbstractNode)
    # Does renew node
    @chain node begin
        dist!(gm, _)
        sample!(gm, _)
        @aside update!(gm, _[1])
    end
end

function dist!(gm::GraphicalModel, node::Initialized)
    # Does renew node
    @assert has_parent(gm, node)
    parent = get_parent(gm, node)
    _ = dist!(gm, parent)

    @chain node begin
        marginalize!(gm, _)
        @aside @assert is_terminal(gm, _)
        @aside update!(gm, _)
    end
end

function dist!(gm::GraphicalModel, node::Marginalized)
    # Does renew node
    @chain node begin
        retract!(gm, _)
        @aside @assert is_terminal(gm, _)
    end
end

dist!(gm::GraphicalModel, node::Realized) = Dirac(node.val)

function rand!(gm::GraphicalModel, node::Initialized)
    @chain node begin
        dist!(gm, _)
        rand!(gm, _)
    end
end

rand!(::GraphicalModel, node::Marginalized) = (node, rand(node.d))
rand!(::GraphicalModel, node::Realized) = (node, node.val)

function retract!(gm::GraphicalModel, node::Marginalized)
    # Does not renew node
    if isnothing(node.marginalized_child)
        return node
    end

    child = gm.nodes[node.marginalized_child]
    _, _ = value!(gm, child)
    return updated(gm, node)
end

observe!(::GraphicalModel, ::Realized, ::Union{Number,AbstractArray}) =
    throw(RealizedObservation())

function observe!(
    gm::GraphicalModel,
    node::AbstractNode,
    value::Union{Number,AbstractArray},
)
    marginalized_node = dist!(gm, node)
    ll = logpdf(marginalized_node.d, value)
    new_node = realize!(gm, marginalized_node, value)
    return new_node, ll
end

function jointdist!(gm::GraphicalModel, child::Initialized, parent::Marginalized)
    return jointdist(parent.d, child.cd)
end

function jointdist!(gm::GraphicalModel, child::Marginalized, parent::Marginalized)
    new_child = dist!(gm, child)
    rev_cd = condition_cd(parent.d, new_child.cd)
    return jointdist(child.d, rev_cd)
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
    parent = gm.nodes[parent_id]
    parent_child_ref = push!(parent.children, id)
    node = Initialized(id, parent_id, parent_child_ref, cd)
    set!(gm, node)
    @debug "Initialize $node"
    return id
end

function value!(gm::GraphicalModel{I}, id::I) where {I}
    @debug "Value $(gm.nodes[id])"
    _, val = value!(gm, gm.nodes[id])
    return val
end

function rand!(gm::GraphicalModel{I}, id::I) where {I}
    _, val = rand!(gm, gm.nodes[id])
    @debug "Rand $(gm.nodes[id]) with value $val"
    return val
end

function observe!(
    gm::GraphicalModel{I},
    id::I,
    value::Union{Number,AbstractArray},
) where {I}
    @debug "Observe $(gm.nodes[id]) with value $value"
    _, ll = observe!(gm, gm.nodes[id], value)
    return ll
end

function dist!(gm::GraphicalModel{I}, id::I) where {I}
    @debug "Dist $(gm.nodes[id])"
    node = dist!(gm, gm.nodes[id])
    return node.d
end

dist(gm::GraphicalModel, id) = dist!(gm, id)

function jointdist!(gm::GraphicalModel{I}, child_id::I, parent_id::I) where {I}
    #return the dist of (child, parent)
    parent = gm.nodes[parent_id]
    child = gm.nodes[child_id]
    @assert child.parent_id == parent.id
    return jointdist!(gm, child, parent)
end
