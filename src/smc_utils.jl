mutable struct Particle{M,R}
    mem::M
    retvalue::R
end

Particle{M}() where {M} = Particle{M,Any}(M(), nothing)
Particle{M,R}() where {M,R} = Particle{M,R}(M(), R())

OnlineSMC.value(p::Particle{M,R}) where {M,R} = p.retvalue
OnlineSMC.loglikelihood(p::Particle{M,R}) where {M,R} = p.mem.loglikelihood

"""
    Given `step!: M x typeof(args)... -> R` which modifies M in place
    invoke [smc_step](@ref) and return a Cloud of Particles
"""
function smc_node_step(
    step!::Function,
    cloud::Cloud{P},
    reset::Bool,
    args...,
) where {P<:Particle}
    @inline proposal!(p::Particle) = (p.retvalue = step!(p.mem, reset, args...))
    return OnlineSMC.smc_step(proposal!, cloud)
end
