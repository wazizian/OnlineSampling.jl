using Revise
using Logging
using IRTools
using OnlineSampling

testdir = dirname(@__FILE__)

io = open("log.txt", "w+")
debuglogger = SimpleLogger(io, Logging.Debug)

entr([testdir], [OnlineSampling]; postpone = false, pause = 0.001) do
    revise(OnlineSampling)
    IRTools.refresh(OnlineSampling.irpass)
    Base.run(`clear`)
    try
        with_logger(debuglogger) do
            include(joinpath(testdir, "runtests.jl"))
        end
    catch e
        if !(e isa LoadError)
            rethrow
        end
    finally
        flush(io)
    end
end
close(io)
