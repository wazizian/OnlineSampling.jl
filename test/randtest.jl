using Test
using Test: AbstractTestSet, Result, Pass, Fail, Broken, Error, get_testset_depth, get_testset
import Test: record, finish
using MacroTools
using Base: AbstractLock, ReentrantLock

const REPEAT = 10
const REQUIRE = 7

macro randtestset(args...)
    isempty(args) && error("No arguments to @randtestset")
    body = esc(args[end])

    repeat_expr = :($REPEAT)
    require_expr = :($REQUIRE)

    args = filter(args) do arg
        @capture(arg, repeat = val_) && (repeat_expr = esc(val)) && return false
        @capture(arg, require = val_) && (require_expr = esc(val)) && return false
        return true
    end
    
    @gensym repeat closure tasks testsets
    code = quote
        @testset RandTestSet repeat=$repeat_expr require=$require_expr $(args[1]) $(map(esc, args[2:end - 1])...) begin
            $testsets = task_local_storage(:__BASETESTNEXT__)
            function $closure()
                task_local_storage(:__BASETESTNEXT__, $testsets)
                $body
            end
            Threads.@threads for _ in 1:$repeat_expr
                $closure()
            end
        end
    end

    return code
end

struct TestID
    orig_expr::String
    source::Union{Nothing,LineNumberNode}
end

TestID(t::Broken) = TestID(string(t.orig_expr), Nothing)
TestID(t::Result) = TestID(string(t.orig_expr), t.source)

struct RandTestSet{L<:AbstractLock} <: AbstractTestSet
    ts::Test.DefaultTestSet
    repeat::Int
    require::Int
    results::Dict{TestID, Any}
    broken::Set{TestID}
    lock::L
end

function RandTestSet(desc::String; repeat::Int=REPEAT, require::Int=REQUIRE)
    @assert require <= repeat
    return RandTestSet(Test.DefaultTestSet(desc), repeat, require, Dict{TestID, Any}(), Set{TestID}(), ReentrantLock())
end

record(rts::RandTestSet, child::AbstractTestSet) = error("RandTestSet must be at bottom level")

function record(rts::RandTestSet, res::Result)
    lock(rts.lock)
    try
        atomic_record(rts, TestID(res), res)
    finally
        unlock(rts.lock)
    end
end

function atomic_record(rts::RandTestSet, id::TestID, res::Broken)
    if id ∉ rts.broken
        push!(rts.broken, id)
        record(rts.ts, res)
    end
end

function atomic_record(rts::RandTestSet, id::TestID, res::Union{Pass, Fail, Error})
    if !haskey(rts.results, id)
        rts.results[id] = Vector{Result}([res])
    else
        push!(rts.results[id], res)
    end
end

function finish(rts::RandTestSet)
    @assert get_testset_depth() > 0
    parent_ts = get_testset()

    for (test_id, res) in rts.results
        n_attempts = length(res)
        @assert n_attempts == rts.repeat

        n_successes = count(r -> typeof(r) == Pass, res)
        if n_successes >= rts.require
            synth_res_ind = findfirst(r -> typeof(r) == Pass, res)
            record(rts.ts, res[synth_res_ind])
        else
            synth_res_ind = findfirst(r -> typeof(r) != Pass, res)
            record(rts.ts, res[synth_res_ind])
        end
    end
    record(parent_ts, rts.ts)
end

        




