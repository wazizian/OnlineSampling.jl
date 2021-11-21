using Pkg

testdir = dirname(@__FILE__)
Pkg.activate(testdir)

using Revise
using OnlineSampling

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
