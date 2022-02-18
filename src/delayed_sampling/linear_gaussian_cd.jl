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

(cd::CdMvNormal)() = MvNormal(cd.linear * cd.μ, cd.Σ)
(cd::CdMvNormal)(parent::AbstractVector) = MvNormal(cd.linear * parent + cd.μ, cd.Σ)
(cd::CdMvNormal)(parent::MvNormal) =
    MvNormal(cd.linear * parent.μ + cd.μ, X_A_Xt(parent.Σ, cd.linear) + cd.Σ)

function condition(parent::MvNormal, child::CdMvNormal, child_val::AbstractArray)
    child_d = child(parent)
    cor = parent.Σ * transpose(child.linear)
    new_cov = parent.Σ - X_invA_Xt(child_d.Σ, cor)
    new_mean = parent.μ + cor * (child_d.Σ \ (child_val - child.μ))
    return MvNormal(new_mean, new_cov)
end

function condition_cd(parent::MvNormal, child::CdMvNormal)
    child_d = child(parent)
    cor = parent.Σ * transpose(child.linear)
    new_cov = parent.Σ - X_invA_Xt(child_d.Σ, cor)
    new_mean = parent.μ - cor * (child_d.Σ \ child.μ)
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
