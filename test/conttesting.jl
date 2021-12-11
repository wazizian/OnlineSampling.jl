using Revise
using OnlineSampling

testdir = dirname(@__FILE__)

entr([testdir], [OnlineSampling]; postpone=false) do
    Base.run(`clear`)
    try
        include(joinpath(testdir, "runtests.jl"))
    catch e
        if !(e isa LoadError)
            rethrow
        end
    end
end
