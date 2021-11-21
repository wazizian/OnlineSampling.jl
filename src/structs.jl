abstract type ConditionalDistribution{F<:VariateForm,S<:ValueSupport} end

struct DummyCD{F, S} <: ConditionalDistribution{F, S} end
DummyCD(d::Distribution{F, S}) where {F, S} = DummyCD{F, S}()

abstract type AbstractNode{I, F, S} end

struct Initialized{I <: Integer, F, S, CD <: ConditionalDistribution{F,S}}<: AbstractNode{I, F, S}
    id::I
    parent_id::Union{I, Nothing}
    parent_child_ref::Union{ListNode{I}, Nothing}
    children::LinkedList{I}
    cd::CD
end

struct Marginalized{I <: Integer, F, S, D <: Distribution{F, S}, CD <: ConditionalDistribution{F,S}} <: AbstractNode{I, F, S} 
    id::I
    parent_id::Union{I, Nothing}
    parent_child_ref::Union{ListNode{I}, Nothing}
    children::LinkedList{I}
    marginalized_child::Union{I, Nothing}
    cd::Union{CD, Nothing}
    d::D
end

# TODO: enforce constraints between T, N and F, S
struct Realized{I <: Integer, F, S, A <: AbstractArray, CD <: ConditionalDistribution{F,S}} <: AbstractNode{I, F, S}
    id::I
    parent_id::Union{I, Nothing}
    parent_child_ref::Union{ListNode{I}, Nothing}
    children::LinkedList{I}
    cd::Union{CD, Nothing}
    val::A
end

const UnionNode = Union{Initialized, Marginalized, Realized}

struct GraphicalModel{I<:Integer, F<:AbstractFloat}
    nodes::Vector{UnionNode}
    last_id::I
    loglikelihood::F
end

function GraphicalModel(::Type{I}) where {I <: Integer}
    GraphicalModel{I, Float64}(Vector{UnionNode}(), convert(I, 0), 0.)
end

# Initial constructors
Marginalized(id::I, d::Distribution) where {I <: Integer} =
    Marginalized(id, nothing, nothing, LinkedList{I}(), nothing, DummyCD(d), d)

Initialized(id::I, parent_id::I, parent_child_ref, cd) where {I <: Integer} =
    Initialized(id, parent_id, parent_child_ref, LinkedList{I}(), cd)

# Conversion constructors
Marginalized(node::Initialized, d::Distribution) =
    Marginalized(node.id, node.parent_id, node.parent_child_ref, node.children, nothing, node.cd, d)

Realized(node::AbstractNode, val::AbstractArray) =
    Realized(node.id, node.parent_id, node.parent_child_ref, node.children, node.cd, val)




