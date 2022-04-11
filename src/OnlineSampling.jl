module OnlineSampling

using Chain
using MacroTools
using MacroTools: prewalk, postwalk
using IRTools
using IRTools: @dynamo, IR, Meta, arguments, xcall, Statement, self
using IRTools.Inner: varmap, Variable
using Accessors
import Distributions
using Distributions:
    Distribution, Normal, MvNormal, AbstractMvNormal, Multivariate, Continuous
using LinearAlgebra
using ConstructionBase
# For llvm code debugging
using InteractiveUtils

using Reexport

include("cond_distr/CondDistr.jl")
import ..CondDistr as CD
import ..CondDistr: CdMvNormal

include("symb_interface.jl")
using .SymbInterface
import .SymbInterface: dist

include("delayed_sampling/DelayedSampling.jl")
import ..DelayedSampling as DS
export DS

include("belief_propagation/Beliefpropagation.jl")
import ..Beliefpropagation as BP
export BP

include("streaming_belief_propagation/StreamingBeliefPropagation.jl")
import ..StreamingBeliefPropagation as SBP
export SBP

include("online_smc/OnlineSMC.jl")
import ..OnlineSMC as SMC
import ..OnlineSMC: Cloud, expectation
export OnlineSMC, Cloud, expectation

include("macro_utils.jl")
include("ir_utils.jl")
include("wrapper_utils.jl")
include("notinit.jl")
include("notinit_propagation.jl")
include("observe.jl")
include("tracked_rv.jl")
include("smc_utils.jl")
include("ir_pass.jl")
include("node_build.jl")
include("node_run.jl")
include("macros.jl")
include("special_nodes.jl")

export @node,
    @nodecall,
    @nodeiter,
    @noderun,
    cst,
    @init,
    @prev,
    @observe,
    dist,
    particle_filter,
    delayed_sampling,
    belief_propagation,
    streaming_belief_propagation
end
