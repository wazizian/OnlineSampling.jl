"""
    Abstract structure which describes the sampling context:
    the loglikelihood and whether ds is enabled
"""
abstract type SamplingCtx end

struct DSOffCtx <: SamplingCtx end

struct DSOnCtx <: SamplingCtx
    gm::DS.GraphicalModel
end
DsOnCtx() = DSOnCtx(DS.GraphicalModel(Int64))

SamplingCtx() = DSOffCtx()

"""
    Abstract structure describing a rv which belongs
    to the Delayed Sampling graph, and which is tracked
"""
abstract type AbstractTrackedRV{T,F,S,D<:Distribution{F,S}} <:
              AbstractTrackedObservation{T,F,S,D} end

"""
    Plain tracked rv, which does not support any operation
    (unsued for now)
"""
struct TrackedRV{T,F,S,D<:Distribution{F,S}} <: AbstractTrackedRV{T,F,S,D}
    gm::DS.GraphicalModel
    id::Int64
end

# TrackedObservation interface
# value(trv::TrackedRV) = DS.value!(trv.gm, trv.id)
# internal_observe(trv::TrackedRV{T}, obs::T) where {T} = DS.observe!(trv.gm, trv.id, obs)

"""
    Tracker for vector-valued r.v. which authorizes linear transformations
"""
struct LinearTracker{
    T<:AbstractVector,
    Linear<:AbstractMatrix,
    D<:Distribution{Multivariate,Continuous},
} <: AbstractTrackedRV{T,Multivariate,Continuous,D}
    gm::DS.GraphicalModel
    id::Int64
    linear::Linear
    offset::T
end
# Overloads
Base.:+(lt::LinearTracker, v::AbstractVector) = (@set lt.offset = lt.offset + v)
Base.:+(v::AbstractVector, lt::LinearTracker) = lt + v
Base.:*(A::AbstractMatrix, lt::LinearTracker) = @chain lt begin
    @set _.linear = A * _.linear
    @set _.offset = A * _.offset
end

# TrackedObservation interface
value(lt::LinearTracker) = linear * DS.value!(lt.gm, lt.id) + offset
internal_observe(lt::LinearTracker{T}, obs::T) where {T<:AbstractVector} =
    DS.observe!(lt.gm, lt.id, linear \ (obs - offset))

"""
   Determine if a r.v. should be a tracked, and by which tracker,
   and sample if needed
"""
track_rv(::DS.GraphicalModel, d::Distribution) = TrackedObservation(rand(d), d)
track_rv(gm::DS.GraphicalModel, d::AbstractMvNormal) =
    LinearTracker{AbstractVector,AbstractMatrix,typeof(d)}(gm, DS.initialize!(gm, d))
# TODO (api impr): clean the two following lines
track_rv(gm::DS.GraphicalModel, t::Tuple{DS.CdMvNormal,Int64}) =
    LinearTracker(gm, DS.initialize!(gm, t...))

"""
    Compute the conditional MvNormal distribution from a LinearTracker
"""
# TODO (api impr): clean the lines
Distributions.MvNormal(
    μ::LinearTracker{T,Linear,D},
    cov,
) where {T,Linear,D<:AbstractMvNormal} = (DS.CdMvNormal(μ.linear, μ.offset, cov), μ.id)

"""
    Wraps a sampled value, and dispact to [track_rv](@ref) is delayed sampling is enabled
"""
internal_rand(::DSOffCtx, d::Distribution) = TrackedObservation(rand(d), d)
internal_rand(ctx::DSOnCtx, d) = track_rv(ctx.gm, d)
