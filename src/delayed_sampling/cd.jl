abstract type ConditionalDistribution{F<:VariateForm,S<:ValueSupport} end

struct DummyCD{F,S} <: ConditionalDistribution{F,S} end
DummyCD(d::Distribution{F,S}) where {F,S} = DummyCD{F,S}()

function condition(parent, child, child_val)
    rev_cd = condition_cd(parent, child)
    return rev_cd(child_val)
end
