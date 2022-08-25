using Test
using Test: AbstractTestSet, Result, Pass, Fail, Broken, Error, get_testset_depth, get_testset
import Test; record, finish

macro randtestset(args...)
    isempty(args) && error("No arguments to @randtestset")
    body = args[end]

    repeat_expr = :(5)
    require_expr = :(4)

    for arg in args[end - 1]
        @capture(arg, repeat = val_) && (repeat_expr = val)
        @capture(arg, require = val_) && (require_expr = val)
    end
end

struct TestID
    test_type::Symbol
    orig_expr::String
    source::Union{Nothing,LineNumberNode}
end

TestID(t::Broken) = TestID(t.test_type, t.orig_expr, Nothing)
TestID(t::Result) = TestID(t.test_type, t.orig_expr, t.source)

struct RandTestSet <: AbstractTestSet
    ts::Test.DefaultTestSet
    repeat::Int
    require::Int
    results::Dict{TestID, Any}
    broken_errors::Set{TestID}
end

RandTestSet(desc::String, repeat::Int=5, require::Int=4) = RandTestSet(Test.DefaultTestSet(desc), repeat, require)

record(rts::RandTestSet, child::AbstractTestSet) = error("RandTestSet must be at bottom level")
record(rts::RandTestSet, res::Result) = record(rts, TestID(res), res)

function record(rts::RandTestSet, id::TestID, res::Union{Broken, Error})
    if !haskey(rts.broken_errors, id)
        rts.results[id] = res
        record(rts.ts, res)
    end
end

function record(rts::RandTestSet, id::TestID, res::Union{Pass, Fail})
    if !haskey(rts.results, id)
        rts.results[id] = Vector{Result}([res])
    else
        push!(rts.results[id], res)
    end
end

function finish(ts::CustomTestSet)
        # just record if we're not the top-level parent
        #     if get_testset_depth() > 0
        #             record(get_testset(), ts)
        #                 end
        #                     ts
        #                     end




