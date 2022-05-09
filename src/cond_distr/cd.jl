abstract type ConditionalDistribution{F<:VariateForm,S<:ValueSupport} end

struct DummyCD{F,S} <: ConditionalDistribution{F,S} end
DummyCD(d::Distribution{F,S}) where {F,S} = DummyCD{F,S}()

function condition_default(parent, child, child_val)
    rev_cd = condition_cd(parent, child)
    return rev_cd(child_val)
end

condition(parent, child, child_val) = condition_default(parent, child, child_val)

condition_cd(parent, child) = error(
    "condition_cd not implemented for parent of type $(typeof(parent)) and child of type $(typeof(child))",
)

function condition(
    parent::Dirac,
    child::ConditionalDistribution,
    child_val::Union{Number,AbstractArray},
)
    return parent
end

function condition_cd(parent::Dirac, child::ConditionalDistribution)
    return parent
end
