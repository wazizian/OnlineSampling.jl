# TODO extend to Geometric

# Only used for type information
(cd::ConditionalDistribution{Univariate,Discrete})() = cd(0.0)
# Bernoulli

struct CdBernoulli <: ConditionalDistribution{Univariate,Discrete} end

(cd::CdBernoulli)(parent::AbstractFloat) = Bernoulli(parent)
(cd::CdBernoulli)(parent::Beta) = Bernoulli(parent.α / (parent.α + parent.β))
(cd::CdBernoulli)(parent::Dirac) = Bernoulli(parent.value)


function condition(parent::Beta, child::CdBernoulli, child_val::Bool)
    return Beta(parent.α + child_val, parent.β + (1 - child_val))
end

# Binomial
# Represents the distribution of child | parent ~ Binomial(n, parent)
struct CdBinomial <: ConditionalDistribution{Univariate,Discrete}
    n::Int
end

(cd::CdBinomial)(parent::AbstractFloat) = Binomial(cd.n, parent)
(cd::CdBinomial)(parent::Beta) = BetaBinomial(cd.n, parent.α, parent.β)
(cd::CdBinomial)(parent::Dirac) = Binomial(cd.n, parent.value)


function condition(parent::Beta, child::CdBinomial, child_val::Int)
    return Beta(parent.α + child_val, parent.β + (child.n - child_val))
end
