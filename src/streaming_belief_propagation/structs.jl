abstract type AbstractNode{F,S} end

const NodeRef = Ref{AbstractNode}

# Self-referencing objects should not be a problem for Julia's
# mark-and-sweep GC
struct Initialized{F,S,CD<:ConditionalDistribution{F,S}} <: AbstractNode{F,S}
    id::NodeRef
    parent_id::NodeRef
    cd::CD
    function Initialized(id, parent_id, cd::CD) where {F,S,CD<:ConditionalDistribution{F,S}}
        node = new{F,S,CD}(id, parent_id, cd)
        id[] = node
        return node
    end
end
struct Marginalized{F,S,D<:Distribution{F,S}} <: AbstractNode{F,S}
    id::NodeRef
    d::D
    function Marginalized(id, d::D) where {F,S,D<:Distribution{F,S}}
        node = new{F,S,D}(id, d)
        id[] = node
        return node
    end
end

struct Realized{F,S,A<:Union{Number,AbstractArray},D<:Distribution{F,S}} <:
       AbstractNode{F,S}
    id::NodeRef
    d::D
    val::A
    function Realized(
        id,
        d::D,
        val::A,
    ) where {F,S,A<:Union{Number,AbstractArray},D<:Distribution{F,S}}
        node = new{F,S,A,D}(id, d, val)
        id[] = node
        return node
    end
end

struct GraphicalModel end

# Convenience constructors
new_id() = NodeRef()
Initialized(parent_id, cd) = Initialized(new_id(), parent_id, cd)
Marginalized(d) = Marginalized(new_id(), d)
Realized(id, A) = Realized(id, Dirac(A), A)

# Conversion constructors
Marginalized(node::Initialized, d::Distribution) = Marginalized(node.id, d)

# Convenience accessors
id(node::AbstractNode) = node.id
