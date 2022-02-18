"""
    Abstract structure which describes the sampling context:
    the loglikelihood and whether ds is enabled
"""
abstract type SamplingCtx end

struct DSOffCtx <: SamplingCtx end

struct DSOnCtx <: SamplingCtx
    gm::DS.GraphicalModel
end
DSOnCtx() = DSOnCtx(DS.GraphicalModel(Int64))

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

"""
    Instantiate a linear tracker
"""
# Note that d is only used for its type and dimensions
function LinearTracker(
    gm::DS.GraphicalModel,
    id::Int64,
    template_d::Distribution{Multivariate,Continuous},
)
    dim = Base.size(template_d)[1]
    elt = Base.eltype(template_d)
    offset = zeros(elt, dim)
    linear = Matrix{elt}(I, dim, dim)
    T = typeof(offset)
    Linear = typeof(linear)
    D = typeof(template_d)
    return LinearTracker{T,Linear,D}(gm, id, linear, offset)
end

# Overloads
Base.:+(lt::LinearTracker, v::AbstractVector) = (@set lt.offset = lt.offset + v)
Base.:+(v::AbstractVector, lt::LinearTracker) = lt + v
Base.:*(A::AbstractMatrix, lt::LinearTracker) = @chain lt begin
    @set _.linear = A * _.linear
    @set _.offset = A * _.offset
end

# TrackedObservation interface
value(lt::LinearTracker) = lt.linear * DS.value!(lt.gm, lt.id) + lt.offset
soft_value(lt::LinearTracker) = lt.linear * DS.rand!(lt.gm, lt.id) + lt.offset
internal_observe(lt::LinearTracker, obs) =
    DS.observe!(lt.gm, lt.id, lt.linear \ (obs - lt.offset))

"""
   Determine if a r.v. should be a tracked, and by which tracker,
   and sample if needed
"""
track_rv(::DS.GraphicalModel, d::Distribution) = TrackedObservation(rand(d), d)
track_rv(gm::DS.GraphicalModel, d::AbstractMvNormal) =
    LinearTracker(gm, DS.initialize!(gm, d), d)
# TODO (api impr): clean the two following lines
track_rv(gm::DS.GraphicalModel, t::Tuple{DS.CdMvNormal,Int64}) =
    LinearTracker(gm, DS.initialize!(gm, t...), t[1]())

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
