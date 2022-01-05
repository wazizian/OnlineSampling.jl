using Revise
using IRTools
using OnlineSampling

testdir = dirname(@__FILE__)

entr([testdir], [OnlineSampling]; postpone = false, pause = 0.001) do
    revise(OnlineSampling)
    IRTools.refresh(OnlineSampling.IRPass())
    Base.run(`clear`)
    try
        include(joinpath(testdir, "runtests.jl"))
    catch e
        if !(e isa LoadError)
            rethrow
        end
    end
end
