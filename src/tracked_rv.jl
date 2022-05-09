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
    to the symbolic  graph, and which is tracked
"""
abstract type AbstractTrackedRV{T,F,S,D<:Distribution{F,S}} <:
              AbstractTrackedObservation{T,F,S,D} end

"""
    Get the distribution of a tracked rv
"""
function dist(rv::AbstractTrackedRV) end

"""
    Unwrap a structure by applying `dist` to tracked RVs
"""
unwrap_dist_tracked_value(x) = unwrap_value(AbstractTrackedRV, x; value = dist)

"""
    Plain tracked rv, which does not support any operation
"""
struct Tracker{T,G<:GraphicalModel,I,F,S,D<:Distribution{F,S}} <: AbstractTrackedRV{T,F,S,D}
    gm::G
    id::I
end

"""
    Constructor for Tracker to ensure interop with Accessor.jl
"""
ConstructionBase.constructorof(
    ::Type{Tracker{T,G,I,F,S,D}},
) where {T,G<:GraphicalModel,I,F,S,D<:Distribution{F,S}} = Tracker{T,G,I,F,S,D}

"""
    Instantiate a tracker
"""
function Tracker(gm::GraphicalModel, id, template_d::D) where {F,S,D<:Distribution{F,S}}
    G = typeof(gm)
    elt = Base.eltype(template_d)
    T = if F == Multivariate
        AbstractVector{elt}
    elseif F == Matrixvariate
        AbstractMatrix{elt}
    else # F == Univariate
        elt
    end
    I = typeof(id)
    return Tracker{T,G,I,F,S,D}(gm, id)
end

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

"""
    Constructor for LinearTracker to ensure interop with Accessor.jl
"""
ConstructionBase.constructorof(
    ::Type{LinearTracker{T,G,I,Linear,D}},
) where {
    T<:AbstractVector,
    I,
    G<:GraphicalModel,
    Linear<:AbstractMatrix,
    D<:Distribution{Multivariate,Continuous},
} = LinearTracker{T,G,I,Linear,D}

# TrackedObservation interface
value(trv::Tracker) = value!(trv.gm, trv.id)
soft_value(trv::Tracker) = rand!(trv.gm, trv.id)
internal_observe(trv::Tracker{T}, obs::T) where {T} = observe!(trv.gm, trv.id, obs)
dist(trv::Tracker) = dist(trv.gm, trv.id)

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
dist(lt::LinearTracker) = dist(lt.gm, lt.id)

Base.size(lt::LinearTracker) = Base.size(lt.offset)

"""
   Determine if a r.v. should be a tracked, and by which tracker,
   and sample if needed
"""
# Default: sample
track_rv(::GraphicalModel, d::Distribution) = TrackedObservation(rand(d), d)

# Roots
track_rv(gm::GraphicalModel, d::AbstractMvNormal) = LinearTracker(gm, initialize!(gm, d), d)
track_rv(gm::GraphicalModel, d::Beta) = Tracker(gm, initialize!(gm, d), d)

# Children
track_rv(gm::GraphicalModel, t::Tuple{CdMvNormal,I}) where {I} =
    LinearTracker(gm, initialize!(gm, t...), t[1]())
track_rv(gm::GraphicalModel, t::Tuple{CdBernoulli,I}) where {I} =
    Tracker(gm, initialize!(gm, t...), t[1]())

"""
    Get the conditional MvNormal distribution from a MvNormal LinearTracker
"""
Distributions.MvNormal(
    μ::AbstractTrackedRV{T,Multivariate,Continuous,D},
    cov,
) where {T<:AbstractVector,D<:AbstractMvNormal} =
    (CdMvNormal(μ.linear, μ.offset, cov), μ.id)

"""
    Get the conditional Bernoulli distribution from a Beta Tracker
"""
Distributions.Bernoulli(
    p::AbstractTrackedRV{T,Univariate,Continuous,D},
) where {T<:Real,D<:Beta} = (CdBernoulli(), p.id)

"""
    Get the conditional Binomial distribution from a Beta Tracker
"""
Distributions.Binomial(
    p::AbstractTrackedRV{T,Univariate,Continuous,D},
    n,
) where {T<:Real,D<:Beta} = (CdBinomial(n), p.id)


"""
    Wraps a sampled value, and dispact to [track_rv](@ref) is delayed sampling is enabled
"""
internal_rand(::OffCtx, d::Distribution) = TrackedObservation(rand(d), d)
internal_rand(ctx::OnCtx, d) = track_rv(ctx.gm, d)
