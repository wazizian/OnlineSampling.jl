module OnlineSampling

using Chain
using MacroTools
using MacroTools: prewalk, postwalk
using IRTools
using IRTools: @dynamo, IR, recurse!, Meta
using IRTools.Inner: update!
using Accessors
using Distributions

using Reexport

include("delayed_sampling/DelayedSampling.jl")
@reexport using ..DelayedSampling

include("node_structs.jl")
include("macro_utils.jl")
include("ir_utils.jl")
include("notinit_removal.jl")
include("observe.jl")
include("ir_pass.jl")
include("node_build.jl")
include("node_run.jl")
include("macros.jl")
include("special_nodes.jl")

export @node, @init, @prev, @observe

end
