mutable struct Particle{M,C<:SamplingCtx,R}
    mem::M
    ctx::C
    retvalue::R
end

Particle{M,C}() where {M,C<:SamplingCtx} = Particle{M,C,Any}(M(), C(), nothing)
Particle{M,C,R}() where {M,C<:SamplingCtx, R} = Particle{M,C,R}(M(), C(),R())

SMC.value(p::Particle) = p.retvalue
SMC.loglikelihood(p::Particle) = p.mem.loglikelihood

"""
    Given `step!: M x typeof(args)... -> R` which modifies M in place
    invoke [smc_step](@ref) and return a Cloud of Particles
"""
function smc_node_step(
    step!::Function,
    cloud::SMC.Cloud{P},
    reset::Bool,
    args...,
) where {P<:Particle}
    @inline proposal!(p::Particle) = (p.retvalue = step!(p.mem, reset, p.ctx, args...))
    return SMC.smc_step(proposal!, cloud)
end
