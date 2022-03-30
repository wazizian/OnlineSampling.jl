function new_id(gm)
    # TODO: this logic will be improved
    @assert length(gm.nodes) == gm.last_id
    id = (gm.last_id += 1)
    return id
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
