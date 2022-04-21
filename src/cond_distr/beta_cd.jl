# TODO extend to Binomial, Geometric

struct CdBernoulli <: ConditionalDistribution{Univariate,Discrete} end

(cd::CdBernoulli)(parent::AbstractFloat) = Bernoulli(parent)
(cd::CdBernoulli)(parent::Beta) = Bernoulli(parent.α / (parent.α + parent.β))
(cd::CdBernoulli)(parent::Dirac) = Bernoulli(parent.value)

function condition(parent::Beta, child::CdBernoulli, child_val::Bool)
    return Beta(parent.α + child_val, parent.β + (1 - child_val))
end

function condition_cd(parent::Beta, child::CdBernoulli)
    return child(parent)
end