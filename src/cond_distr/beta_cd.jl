# TODO extend to Binomial, Geometric

struct CdBernoulli <: ConditionalDistribution{Univariate,Discrete} end

(cd::CdBernoulli)(parent::AbstractFloat) = Bernoulli(parent)
(cd::CdBernoulli)(parent::Beta) = Bernoulli(parent.α / (parent.α + parent.β))
(cd::CdBernoulli)(parent::Dirac) = Bernoulli(parent.value)
# Only used for type information
(cd::CdBernoulli)() = cd(0.0)

function condition(parent::Beta, child::CdBernoulli, child_val::Bool)
    return Beta(parent.α + child_val, parent.β + (1 - child_val))
end
