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

function Base.show(io::IO, p::MemParticle)
    print(io, "mem = $(unwrap_soft_tracked_value(p.mem)), ctx = $(unwrap_soft_tracked_value(p.ctx)), loglikelihood = $(p.loglikelihood), retvalue = $(unwrap_soft_tracked_value(p.retvalue))")
end

"""
    Particle output of the reactive program
"""
struct RetParticle{R,D}
    retvalue::R
    symb::D
end

SMC.value(p::RetParticle) = p.retvalue

dist(p::RetParticle) = p.symb

function Base.show(io::IO, p::RetParticle)
    print(io, "retvalue = $(p.retvalue)")
end

function Base.show(io::IO, p::RetParticle{R, D}) where {R, D <: Distribution}
    print(io, "retvalue = $(p.retvalue), distr = $(p.symb)")
end

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
    construct a `augm_proposal : MemParticle{R} x typesof(args') -> MemParticle{RxR}`
"""
function augm_proposal(p::P, step::F, reset::Bool, args...) where {P<:MemParticle,F<:Function}
    mem, ll, ret = step(p.mem, reset, p.ctx, args...)
    return MemParticle(mem, p.ctx, ll, (p.retvalue, ret))
end

"""
    Given `step: M x Bool x Ctx x typesof(args)... -> M x Float x R`
    invoke [smc_step](@ref) and return a Cloud of MemParticles
"""
function smc_node_step(
    step::F,
    cloud::SMC.Cloud{P},
    reset::Bool,
    resample_threshold::Float64,
    args...,
) where {F<:Function,P<:MemParticle}
    return SMC.smc_step(proposal, resample_threshold, cloud, step, reset, args...)
end

"""
    Helper function to create particules for joint pF
"""
function replay_particule(prev_p, curr_p)
    return @chain curr_p.ctx begin
        @set _.replay = true
        @set prev_p.ctx = _
    end
end

"""
    Given clouds at times t-1 and t of size N with AdvPFCtx, return a cloud 
    of size N^2 representing the joint distribution
"""
function smc_joint_node_step(
    step::F,
    prev_cloud::SMC.Cloud{prev_P},
    curr_cloud::SMC.Cloud{curr_P},
    args...,
    ) where {F<:Function, prev_P<:MemParticle, curr_P<:MemParticle}
    # Disable resampling
    resample_threshold = 0.
    # No reset
    reset = false
    # @show prev_cloud
    # @show curr_cloud
    obs_weights = reshape(curr_cloud.logweights - prev_cloud.logweights, 1, :)
    @assert size(obs_weights) == (1, length(curr_cloud))
    prev_cloud = SMC.resample_cloud(prev_cloud)
    curr_cloud = SMC.resample_cloud(curr_cloud)
    meta_particles = map(Base.splat(replay_particule), Base.product(prev_cloud.particles, curr_cloud.particles))
    meta_weights = repeat(prev_cloud.logweights, 1, length(curr_cloud)) # .+ obs_weights
    meta_cloud = Cloud(meta_weights, meta_particles)
    new_meta_cloud = SMC.smc_step(augm_proposal, resample_threshold, meta_cloud, step, reset, args...)
    new_meta_weights = @chain new_meta_cloud.logweights begin
    #    _ .- reshape(diag(_), 1, :)
        _ .- logsumexp(_; dims=1)
        _ .+ obs_weights
        _ .- logsumexp(_; dims=2)
    end
    # @show exp.(prev_cloud.logweights)
    # @show exp.(curr_cloud.logweights)
    # @show meta_weights
    # @show prev_cloud.particles
    # @show curr_cloud.particles
    # @show new_meta_weights
    normalized_new_meta_cloud = @set new_meta_cloud.logweights = new_meta_weights
    # @show meta_cloud
    # @show new_meta_cloud
    # @show normalized_new_meta_cloud
    return normalized_new_meta_cloud
end

"""
    Transform a cloud of `MemParticle` into a sanitized
    cloud of arrays
"""
# Note: this a slight abuse of the cloud structure
# since it does not have a loglikelihood method
function sanitize_return(cloud::Cloud{P}) where {M, C<:OnCtx, R, P<:MemParticle{M, C, R}}
    tasks = [Threads.@spawn RetParticle(unwrap_soft_tracked_value(p.retvalue), unwrap_dist_tracked_value(p.retvalue)) for p in cloud.particles]
    new_particles = map(fetch, tasks)
    return Cloud(cloud.logweights, new_particles)
end

function sanitize_return(cloud::Cloud{P}) where {M, C<:PFCtx, R, P<:MemParticle{M, C, R}}
    tasks = [Threads.@spawn RetParticle(unwrap_soft_tracked_value(p.retvalue), Nothing) for p in cloud.particles]
    new_particles = map(fetch, tasks)
    return Cloud(cloud.logweights, new_particles)
end
