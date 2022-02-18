struct Particle{M,C<:SamplingCtx,R}
    mem::M
    ctx::C
    loglikelihood::Float64
    retvalue::R
end

Particle{M,C,R}() where {M,C<:SamplingCtx,R} = Particle{M,C,R}(M(), C(), 0.0, R())
Particle{C}() where {C<:SamplingCtx} = Particle{Nothing,C,Nothing}()

SMC.value(p::Particle) = p.retvalue
SMC.loglikelihood(p::Particle) = p.loglikelihood

"""
    Given `step: M x Bool x Ctx x typesof(args)... -> M x Float x R`
    construct a `proposal : Particle x typesof(args') -> Particle`
"""
function proposal(p::P, step::F, reset::Bool, args...) where {P<:Particle,F<:Function}
    mem, ll, ret = step(p.mem, reset, p.ctx, args...)
    return Particle(mem, p.ctx, ll, ret)
end

"""
    Given `step: M x Bool x Ctx x typesof(args)... -> M x Float x R`
    invoke [smc_step](@ref) and return a Cloud of Particles
"""
function smc_node_step(
    step::F,
    cloud::SMC.Cloud{P},
    reset::Bool,
    args...,
) where {F<:Function,P<:Particle}
    return SMC.smc_step(proposal, cloud, step, reset, args...)
end

"""
    Sanitize cloud for return
"""
function sanitize_return(cloud::Cloud{P}) where {P<:Particle}
    new_particles = map(cloud.particles) do p
        return @set p.retvalue = unwrap_soft_tracked_value(p.retvalue)
    end
    return @set cloud.particles = new_particles
end
