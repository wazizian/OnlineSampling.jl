using Test

struct TS <: Test.AbstractTestSet end

function TS(desc; exit_on_error=false)
    if exit_on_error
        Test.FallbackTestSet()
    else
        Test.DefaultTestSet(desc)
    end
end

# Why FallBackTestSet does not satisfy the right interface is beyond me
# However, this needs to be fixed here for the nest test sets
Test.FallbackTestSet(desc::AbstractString) = Test.FallbackTestSet()

#TODO: the output of FallbaclTestSet is not pretty
