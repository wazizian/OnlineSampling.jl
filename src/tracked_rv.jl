"""
    Abstract structure which describes the sampling context:
    whether symbolic inference is enabled and, if this is the case, which one.
"""
abstract type SamplingCtx end

struct OffCtx <: SamplingCtx end
SamplingCtx() = OffCtx()

struct DSOnCtx <: SamplingCtx
    gm::DS.GraphicalModel
end
DSOnCtx() = DSOnCtx(DS.GraphicalModel(Int64))

struct BPOnCtx <: SamplingCtx
    gm::BP.GraphicalModel
end
BPOnCtx() = BPOnCtx(BP.GraphicalModel(Int64))

struct SBPOnCtx <: SamplingCtx
    gm::SBP.GraphicalModel
end
SBPOnCtx() = SBPOnCtx(SBP.GraphicalModel())

const OnCtx = Union{DSOnCtx,BPOnCtx,SBPOnCtx}
const GraphicalModel = Union{DS.GraphicalModel,BP.GraphicalModel,SBP.GraphicalModel}

"""
    Enum type to choose the inference algorithm
"""
@enum Algorithms begin
    particle_filter
    delayed_sampling
    belief_propagation
    streaming_belief_propagation
end

"""
    Map algorithm to context type
"""
function choose_ctx_type(algo::Algorithms)
    (algo == delayed_sampling) && return DSOnCtx
    (algo == belief_propagation) && return BPOnCtx
    (algo == streaming_belief_propagation) && return SBPOnCtx
    return OffCtx
end

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
    id::Any
end

# TrackedObservation interface
# value(trv::TrackedRV) = DS.value!(trv.gm, trv.id)
# internal_observe(trv::TrackedRV{T}, obs::T) where {T} = DS.observe!(trv.gm, trv.id, obs)

"""
    Tracker for vector-valued r.v. which authorizes linear transformations
"""
struct LinearTracker{
    T<:AbstractVector,
    G<:GraphicalModel,
    I,
    Linear<:AbstractMatrix,
    D<:Distribution{Multivariate,Continuous},
} <: AbstractTrackedRV{T,Multivariate,Continuous,D}
    gm::G
    id::I
    linear::Linear
    offset::T
end

ConstructionBase.constructorof(
    ::Type{LinearTracker{T,G,I,Linear,D}},
) where {
    T<:AbstractVector,
    I,
    G<:GraphicalModel,
    Linear<:AbstractMatrix,
    D<:Distribution{Multivariate,Continuous},
} = LinearTracker{T,G,I,Linear,D}

"""
    Pretty-printing of a linear tracker
"""
function Base.show(io::IO, lt::LinearTracker)
    print(
        io,
        "node = $(SymbInterface.get_node(lt.gm, lt.id)), linear = $(lt.linear), offset = $(lt.offset)",
    )
end

"""
    Instantiate a linear tracker
"""
# Note that d is only used for its type and dimensions
function LinearTracker(
    gm::GraphicalModel,
    id,
    template_d::Distribution{Multivariate,Continuous},
)
    G = typeof(gm)
    dim = Base.size(template_d)[1]
    elt = Base.eltype(template_d)
    offset = zeros(elt, dim)
    linear = Matrix{elt}(LinearAlgebra.I, dim, dim)
    T = typeof(offset)
    Linear = typeof(linear)
    D = typeof(template_d)
    I = typeof(id)
    return LinearTracker{T,G,I,Linear,D}(gm, id, linear, offset)
end

# Overloads
Base.:+(lt::LinearTracker, v::AbstractVector) = (@set lt.offset = lt.offset + v)
Base.:+(v::AbstractVector, lt::LinearTracker) = lt + v
Base.:*(A::AbstractMatrix, lt::LinearTracker) = @chain lt begin
    @set _.linear = A * _.linear
    @set _.offset = A * _.offset
end

# TrackedObservation interface
value(lt::LinearTracker) = lt.linear * value!(lt.gm, lt.id) + lt.offset
soft_value(lt::LinearTracker) = lt.linear * rand!(lt.gm, lt.id) + lt.offset
internal_observe(lt::LinearTracker, obs) =
    observe!(lt.gm, lt.id, lt.linear \ (obs - lt.offset))

Base.size(lt::LinearTracker) = Base.size(lt.offset)

"""
   Determine if a r.v. should be a tracked, and by which tracker,
   and sample if needed
"""
track_rv(::GraphicalModel, d::Distribution) = TrackedObservation(rand(d), d)
track_rv(gm::GraphicalModel, d::AbstractMvNormal) = LinearTracker(gm, initialize!(gm, d), d)
# TODO (api impr): clean the two following lines
track_rv(gm::GraphicalModel, t::Tuple{CdMvNormal,I}) where {I} =
    LinearTracker(gm, initialize!(gm, t...), t[1]())

"""
    Compute the conditional MvNormal distribution from a LinearTracker
"""
# TODO (api impr): clean the lines
Distributions.MvNormal(
    μ::LinearTracker{T,G,I,Linear,D},
    cov,
) where {G<:GraphicalModel,I,T,Linear,D<:AbstractMvNormal} =
    (CdMvNormal(μ.linear, μ.offset, cov), μ.id)

"""
    Wraps a sampled value, and dispact to [track_rv](@ref) is delayed sampling is enabled
"""
internal_rand(::OffCtx, d::Distribution) = TrackedObservation(rand(d), d)
internal_rand(ctx::OnCtx, d) = track_rv(ctx.gm, d)
