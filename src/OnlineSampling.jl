module OnlineSampling

using Chain
using MacroTools
using MacroTools: prewalk, postwalk
using IRTools
using Accessors

using Reexport

include("delayed_sampling/DelayedSampling.jl")
@reexport using ..DelayedSampling

include("node_structs.jl")
include("macro_utils.jl")
include("nothing_removal.jl")
include("node_build.jl")
include("node_run.jl")
include("macros.jl")

export @node

end
