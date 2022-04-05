@testset "counter" begin
    @node function counter(arr)
        @init i = 1
        i = (@prev i) + 1
        push!(arr, i)
    end

    @test @isdefined counter

    arr = Vector{Int}()

    # call node for 10 iterations
    @noderun T = 10 counter(cst(arr))

    @test arr == collect(1:10)
end

@testset "iter counter" begin
    @node function counter()
        @init i = 1
        i = (@prev i) + 1
        return i
    end

    @test @isdefined counter

    # call node for 10 iterations
    ret = @noderun T = 10 counter()
    @test ret == 10

    iter = @nodeiter T = 10 counter()
    @test Base.IteratorSize(typeof(iter)) == Base.HasLength()
    @test length(iter) == 10
    @test collect(iter) == collect(1:10)
end

@testset "iter args" begin
    @node function counter(x)
        return x
    end

    @test @isdefined counter

    # call node for 10 iterations
    iter = @nodeiter counter(1:10)
    @test Base.IteratorSize(typeof(iter)) == Base.HasLength()
    @test length(iter) == 10
    @test collect(iter) == collect(1:10)
end

@testset "nested counter" begin
    incr_fun(x::Int)::Int = x + 1
    @assert @isdefined(incr_fun)

    @node function pure_counter()::Int
        @init x = 1
        x = incr_fun(@prev(x))
    end
    @node function counter(arr)
        @init reset = false
        reset = (@prev(i) == 5)
        i = @nodecall reset pure_counter()
        push!(arr, i)
        return i
    end

    @test @isdefined pure_counter
    @test @isdefined counter

    arr = Vector{Int}()
    ret = @noderun T = 10 counter(cst(arr))
    @test ret == 5

    arr = Vector{Int}()
    @noderun T = 10 counter(cst(arr))
    @test arr == cat(collect(1:5), collect(1:5), dims = 1)
end

@testset "nothing propagation" begin
    @node function f(arr)
        @init i = true
        i = !@prev(i)
        push!(arr, i)
    end
    arr = []
    @test (@noderun T = 2 f(cst(arr)); arr == [true, false])
end

@testset "mutable streams" begin
    @node function f(arr)
        @init m = [2, 2]
        m = [1, 2]
        m[1] = 2
        push!(arr, deepcopy(@prev(m)))
    end
    arr = []
    @noderun T = 2 f(cst(arr))
    @test arr[1] == [2, 2]
    @test length(arr) == 1
end

@testset "delayed counter" begin
    @node function f(arr)
        @init x = 0
        @init y = 0
        x = (@prev x) + 1
        y = @prev x
        push!(arr, y)
    end
    arr = []
    @noderun T = 5 f(cst(arr))
    @test arr == vcat([0], collect(0:3))
end

@testset "reversed def & prev" begin
    @node function f(arr)
        @init y = 0
        y = @prev(y) + 1
        push!(arr, @prev(y))
    end
    arr = []
    @noderun T = 5 f(cst(arr))
    @test arr == collect(0:3)
end

@testset "pathological prev" begin
    @node function f(arr)
        @init x = 0
        @init y = 0
        y = @prev x
        x = ((a, b) -> (push!(arr, a); b))(y, (@prev y) + 1)
        @test x isa Real
    end
    arr = []
    @noderun T = 5 f(cst(arr))
    @test arr == [0, 1, 1, 2]
end

@testset "ill-formed prev" begin
    @node function f()
        y = @prev(y) + 1
    end
    @test_throws MethodError (@noderun T = 2 f())
end

@testset "invalid argument" begin
    @node myparticularfunction(x::Bool) = x
    @test_throws MethodError (@noderun T = 1 myparticularfunction(0))
end

@testset "one line counter" begin
    @node function f(arr)
        x = (@prev x) + (@init x = 1)
        push!(arr, x)
    end
    arr = []
    # Due to design change, @init statements
    # are not excuted anymore on 
    # non-reset iterations
    @test_broken (@noderun T = 5 f(cst(arr)))
    @test_broken arr == collect(1:5)
end

@testset "side-effect init" begin
    @node function f(arr)
        @init x = (push!(arr, 0); 1)
    end
    arr = []
    @noderun T = 5 f(cst(arr))
    # Due to design change, @init statements
    # are not excuted anymore on 
    # non-reset iterations
    @test arr == [0]
end

@testset "return node" begin
    @node function counter()
        @init x = 1
        x = @prev(x) + 1
        return x
    end
    @node function g()
        return @nodecall counter()
    end
    @node function f(arr)
        x = @nodecall g()
        push!(arr, x)
    end

    arr = []
    @noderun T = 5 f(cst(arr))
    @test arr == collect(1:5)

    @test collect(@nodeiter T = 5 g()) == collect(1:5)
end
