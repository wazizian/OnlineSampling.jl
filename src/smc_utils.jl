"""
    Particle structure for the reactive program
"""
struct MemParticle{M,C<:SamplingCtx,R}
    mem::M
    ctx::C
    loglikelihood::Float64
    retvalue::R
end

MemParticle{M,C,R}() where {M,C<:SamplingCtx,R} = MemParticle{M,C,R}(M(), C(), 0.0, R())
MemParticle{C}() where {C<:SamplingCtx} = MemParticle{Nothing,C,Nothing}()

SMC.value(p::MemParticle) = p.retvalue
SMC.loglikelihood(p::MemParticle) = p.loglikelihood

"""
    Particle output of the reactive program
"""
struct RetParticle{R}
    loglikelihood::Float64
    retvalue::R
end

SMC.value(p::RetParticle) = p.retvalue
SMC.loglikelihood(p::RetParticle) = p.loglikelihood

"""
    Given `step: M x Bool x Ctx x typesof(args)... -> M x Float x R`
    construct a `proposal : MemParticle x typesof(args') -> MemParticle`
"""
function proposal(p::P, step::F, reset::Bool, args...) where {P<:MemParticle,F<:Function}
    mem, ll, ret = step(p.mem, reset, p.ctx, args...)
    return MemParticle(mem, p.ctx, ll, ret)
end

"""
    Given `step: M x Bool x Ctx x typesof(args)... -> M x Float x R`
    invoke [smc_step](@ref) and return a Cloud of MemParticles
"""
function smc_node_step(
    step::F,
    cloud::SMC.Cloud{P},
    reset::Bool,
    args...,
) where {F<:Function,P<:MemParticle}
    return SMC.smc_step(proposal, cloud, step, reset, args...)
end

"""
    Transform a cloud of `MemParticle` into a sanitized
    cloud of arrays
"""
# Note: this a slight abuse of the cloud structure
# since it does not have a loglikelihood method
function sanitize_return(cloud::Cloud{P}) where {P<:MemParticle}
    new_values = map(cloud.particles) do p
        unwrap_soft_tracked_value(p.retvalue)
    end
    return Cloud(cloud.logweights, new_values)
end
