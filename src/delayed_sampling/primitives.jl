function primitive_marginalize_child(child::Initialized, parent::Marginalized) 
    child_d = child.cd(parent.d)
    return Marginalized(child, child_d)
end

function primitive_marginalize_child(child::Initialized, parent::Realized)
    child_d = child.cd(parent.val)
    return Marginalized(child, child_d)
end

function primitive_marginalize_parent(child::Realized, parent::Marginalized)
    new_parent_d = condition(parent.d, child.cd, child.val)
    return @set parent.d = new_parent_d
end

function is_terminal(gm::GraphicalModel{I}, node::AbstractNode{I}) where {I <: Integer}
    node isa Marginalized && isnothing(node.marginalized_child)
end

function is_inv_sat(gm::GraphicalModel{I}, node::AbstractNode) where {I <: Integer}
    first_inv = !(node isa Marginalized) || (!(has_parent(gm, node)) || get_parent(gm, node) isa Marginalized)
    n_marginalized_children = count(child -> gm.nodes[child] isa Marginalized, node.children)
    if node isa Marginalized
        second_inv = (n_marginalized_children == 0 && isnothing(node.marginalized_child)) ||
                 (n_marginalized_children == 1 && !isnothing(node.marginalized_child) &&
                  gm.nodes[node.marginalized_child] isa Marginalized &&
                  node.marginalized_child in node.children)
    else
        second_inv = n_marginalized_children == 0
    end
    parent_inv = (!isnothing(node.cd)) || (isnothing(node.parent))
    return first_inv && second_inv && parent_inv
end

function is_inv_sat(gm::GraphicalModel{I}) where {I <: Integer}
    return all(node -> is_inv_sat(gm, node), gm.nodes)
end

function new_id(gm)
    # TODO: this logic will be improved
    @assert length(gm.nodes) == gm.last_id
    id = gm.last_id + 1
    return (@set gm.last_id = id), id
end

function set!(gm::GraphicalModel, node::AbstractNode)
    # TODO: this logic will be improved
    id = node.id
    if id > length(gm.nodes)
        @assert id == length(gm.nodes) + 1
        push!(gm.nodes, node)
    else
        gm.nodes[id] = node
    end
end

get_parent(gm, node) = gm.nodes[node.parent_id]
has_parent(gm, node) = !isnothing(node.parent_id)
update!(gm, node) = gm.nodes[node.id] = node
updated(gm, node) = gm.nodes[node.id]

function add_marginalized_child!(gm::GraphicalModel, child::Marginalized)
    if !has_parent(gm, child)
        return
    end

    @chain get_parent(gm, child) begin
        @aside @assert isnothing(_.marginalized_child) || _.marginalized_child == child.id
        @set _.marginalized_child = child.id
        update!(gm, _)
    end
end

function rm_marginalized_child!(gm::GraphicalModel, child::Marginalized)
    if !has_parent(gm, child)
        return
    end

    @chain get_parent(gm, child) begin
        @set _.marginalized_child = nothing
        update!(gm, _)
    end
end

function update_loglikelihood!(gm::GraphicalModel, ll::AbstractFloat)
    gm.loglikelihood[] += ll
end
