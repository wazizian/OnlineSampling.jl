module OnlineSampling

using Chain
using MacroTools
using MacroTools: prewalk, postwalk
using Cassette
using Accessors

using Reexport

include("delayed_sampling/DelayedSampling.jl")
@reexport using ..DelayedSampling

include("structs.jl")
include("macros.jl")

export @node

end
