mutable struct MvParticle
    val::Vector{Float64}
    loglikelihood::Float64
end
MvParticle() = MvParticle([0.0], 0.0)
OnlineSMC.value(p::MvParticle) = p.val
OnlineSMC.loglikelihood(p::MvParticle) = p.loglikelihood

rankone(x::AbstractVector) = x * x'

Statistics.cov(cloud::OnlineSMC.Cloud{MvParticle}) =
    expectation(rankone, cloud) - rankone(expectation(identity, cloud))
Statistics.mean(cloud::OnlineSMC.Cloud{MvParticle}) = expectation(identity, cloud)
