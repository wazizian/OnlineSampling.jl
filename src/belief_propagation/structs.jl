abstract type AbstractNode{I,F,S} end

struct Initialized{I<:Integer,F,S,CD<:ConditionalDistribution{F,S}} <: AbstractNode{I,F,S}
    id::I
    parent_id::Union{I,Nothing}
    cd::CD
end
struct Marginalized{I<:Integer,F,S,D<:Distribution{F,S}} <: AbstractNode{I,F,S}
    id::I
    d::D
end

struct Realized{I<:Integer,F,S,A<:Union{Number,AbstractArray},D<:Distribution{F,S}} <:
       AbstractNode{I,F,S}
    id::I
    d::D
    val::A
end
mutable struct GraphicalModel{I<:Integer}
    nodes::Vector{AbstractNode}
    last_id::I
end

function GraphicalModel(::Type{I}) where {I<:Integer}
    GraphicalModel{I}(Vector{AbstractNode}(), convert(I, 0))
end

function GraphicalModel(nodes::Vector{T}, last_id::I) where {T<:AbstractNode,I<:Integer}
    GraphicalModel{I}(Vector{AbstractNode}(nodes), last_id)
end

# Initial constructors
Realized(id::I, A) where {I<:Integer} = Realized(id, Dirac(A), A)

#Marginalized(id::I, d::Distribution) where {I<:Integer} =
#    Marginalized(id, d)


# Conversion constructors
Marginalized(node::Initialized, d::Distribution) = Marginalized(node.id, d)
