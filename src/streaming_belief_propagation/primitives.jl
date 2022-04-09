
has_parent(node::Initialized) = node.parent_id != nothing
has_parent(::AbstractNode) = false

function get_node(ref::NodeRef)
    @assert isassigned(ref)
    return ref[]
end

get_node(::GraphicalModel, ref::NodeRef) = get_node(ref)

get_parent_id(node::Initialized) = node.parent_id

get_parent(node::Initialized) = (get_node ∘ get_parent_id)(node)
