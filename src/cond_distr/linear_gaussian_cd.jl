# Represents the distribution of child | parent ~ N(linear * parent + mean, Σ)
# TODO: enforce homogenous float datatype
struct CdMvNormal{Linear<:StridedMatrix,Mean<:AbstractVector,Cov<:AbstractPDMat} <:
       ConditionalDistribution{Multivariate,Continuous}
    linear::Linear
    μ::Mean
    Σ::Cov
end

CdMvNormal(
    linear::Linear,
    μ::Mean,
    Σ::Cov,
) where {Linear<:StridedMatrix,Mean,Cov<:AbstractPDMat} =
    CdMvNormal{Linear,Mean,Cov}(linear, μ, Σ)
CdMvNormal(
    linear::Linear,
    μ::Mean,
    Σ::Cov,
) where {Linear<:AbstractArray,Mean,Cov<:AbstractArray} =
    CdMvNormal(Array(linear), μ, PDMat(Array(Σ)))

(cd::CdMvNormal)() = MvNormal(cd.μ, cd.Σ)
(cd::CdMvNormal)(parent::AbstractVector) = MvNormal(cd.linear * parent + cd.μ, cd.Σ)
(cd::CdMvNormal)(parent::MvNormal) =
    MvNormal(cd.linear * parent.μ + cd.μ, X_A_Xt(parent.Σ, cd.linear) + cd.Σ)
(cd::CdMvNormal)(parent::Dirac) = MvNormal(cd.linear * parent.value + cd.μ, cd.Σ)

function condition(parent::MvNormal, child::CdMvNormal, child_val::AbstractArray)
    child_d = child(parent)
    cor = parent.Σ * transpose(child.linear)
    new_cov = parent.Σ - X_invA_Xt(child_d.Σ, cor)
    new_mean = parent.μ + cor * (child_d.Σ \ (child_val - child_d.μ))
    return MvNormal(new_mean, new_cov)
end


function condition_cd(parent::MvNormal, child::CdMvNormal)
    child_d = child(parent)
    cor = parent.Σ * transpose(child.linear)
    new_cov = parent.Σ - X_invA_Xt(child_d.Σ, cor)
    new_mean = parent.μ - cor * (child_d.Σ \ child_d.μ)
    linear = transpose(child_d.Σ \ transpose(cor))
    return CdMvNormal(linear, new_mean, new_cov)
end


function jointdist(parent::MvNormal, child::CdMvNormal)
    child_d = child(parent)
    cor = parent.Σ * transpose(child.linear)
    new_mean = cat(child_d.μ, parent.μ; dims = 1)
    new_cov = [child_d.Σ transpose(cor); cor parent.Σ]
    return MvNormal(new_mean, new_cov)
end

struct CdNormal{F<:AbstractFloat} <: ConditionalDistribution{Univariate,Continuous}
    linear::F
    μ::F
    σ::F
end

(cd::CdNormal)() = Normal(cd.μ, cd.σ)
(cd::CdNormal)(parent::AbstractFloat) = Normal(cd.linear * parent + cd.μ, cd.σ)
(cd::CdNormal)(parent::Normal) =
    Normal(cd.linear * parent.μ + cd.μ, sqrt(cd.linear^2 * parent.σ^2 + cd.σ^2))

function condition_cd(parent::Normal, child::CdNormal)
    child_d = child(parent)
    cor = parent.σ^2 * child.linear
    new_var = parent.σ^2 - (cor / child_d.σ)^2
    new_linear = cor / (child_d.σ^2)
    new_mean = parent.μ - new_linear * child_d.μ
    return CdNormal(new_linear, new_mean, sqrt(new_var))
end
