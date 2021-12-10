module OnlineSampling

using Reexport

include("delayed_sampling/DelayedSampling.jl")
@reexport using ..DelayedSampling

end
