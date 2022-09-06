using Test
using Test: AbstractTestSet, Result, Pass, Fail, Broken, Error, get_testset_depth, get_testset
import Test: record, finish
using MacroTools
using Base: AbstractLock, ReentrantLock
using Accessors

const REPEAT = 10
const REQUIRE = 7

const REP_SYMB = :__RANDTESTREPEAT__

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
    
    @gensym repeat closure tasks testsets rep
    code = quote
        @testset RandTestSet repeat=$repeat_expr require=$require_expr $(args[1]) $(map(esc, args[2:end - 1])...) begin
            $testsets = task_local_storage(:__BASETESTNEXT__)
            function $closure($rep)
                task_local_storage(:__BASETESTNEXT__, $testsets)
                task_local_storage($(QuoteNode(REP_SYMB)), $rep)
                $body
            end
            Threads.@threads for $rep in 1:$repeat_expr
                $closure($rep)
            end
        end
    end
    return code
end

### Test results storage
struct TestID
    orig_expr::String
    source::Union{Nothing,LineNumberNode}
end

TestID(t::Broken) = TestID(string(t.orig_expr), nothing)
TestID(t::Result) = TestID(string(t.orig_expr), t.source)

struct TestRepID
    t::TestID
    rep::Int
end

TestRepID(t::Result, rep::Int) = TestRepID(TestID(t), rep)

const RawResults = Dict{TestRepID, Vector{Result}}

function add_result!(results::RawResults, id::TestRepID, res::Result)
    if !haskey(results, id)
        results[id] = Vector{Result}([res])
        # no size hint, because asynchronous (and exhaustive lookup may be expensive)
    else
        push!(results[id], res)
    end
end

const TestInternalRepID = TestRepID
const Results = Dict{TestRepID, Vector{Result}}

function convert_results(results::RawResults, repeat::Int)::Results
    new_results = Results()
    for (id, vec_res) in results
        for (internal_rep, res) in enumerate(vec_res)
            new_id = TestInternalRepID(id.t, internal_rep)
            if !haskey(new_results, new_id)
                new_results[new_id] = Vector{Result}([res])
                # size hint, no check done here, they are done later
                sizehint!(new_results[new_id], repeat)
            else
                push!(new_results[new_id], res)
            end
        end
    end
    return new_results
end

### Custom testset
struct RandTestSet{L<:AbstractLock} <: AbstractTestSet
    ts::Test.DefaultTestSet
    repeat::Int
    require::Int
    results::RawResults
    lock::L
end

function RandTestSet(desc::String; repeat::Int=REPEAT, require::Int=REQUIRE)
    @assert require <= repeat
    return RandTestSet(Test.DefaultTestSet(desc), repeat, require, RawResults(), ReentrantLock())
end

record(rts::RandTestSet, child::AbstractTestSet) = error("RandTestSet must be at bottom level")

function record(rts::RandTestSet, res::Result)
    lock(rts.lock)
    try
        atomic_record(rts, res)
    finally
        unlock(rts.lock)
    end
end

function atomic_record(rts::RandTestSet, res::Result)
    rep = task_local_storage(REP_SYMB)
    id = TestRepID(res, rep)
    add_result!(rts.results, id, res)
end

function finish(rts::RandTestSet)
    @assert get_testset_depth() > 0
    parent_ts = get_testset()

    results = convert_results(rts.results, rts.repeat)

    for (test_id, res) in results
        n_attempts = length(res)
        @assert n_attempts == rts.repeat (n_attempts, rts.repeat)

        n_successes = count(r -> typeof(r) == Pass, res)
        # To debug this script
        # @show (test_id, n_successes)

        if any(r -> typeof(r) == Broken, res)
            synth_res_ind = findfirst(r -> typeof(r) == Broken, res)
            record(rts.ts, res[synth_res_ind])
        elseif n_successes >= rts.require
            synth_res_ind = findfirst(r -> typeof(r) == Pass, res)
            record(rts.ts, res[synth_res_ind])
        else
            printstyled("Error During Repeated Random Test: "; color = :red, bold = true)
            println("Test failed $(rts.repeat - n_successes) out of $(rts.repeat) runs, here is a sample failure")
            # To debug this script
            # @show test_id
            synth_res_ind = findfirst(r -> typeof(r) != Pass, res)
            record(rts.ts, res[synth_res_ind])
        end
    end
    record(parent_ts, rts.ts)
end

        




