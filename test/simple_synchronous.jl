@testset "counter" begin
    @node function counter(arr)
        @init i = 1
        i = (@prev i) + 1
        push!(arr, i)
    end

    @test @isdefined counter

    arr = Vector{Int}()

    # call node for 10 iterations
    @node T = 10 counter(arr)

    @test arr == collect(1:10)
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
        i = @node reset pure_counter()
        push!(arr, i)
    end

    @test @isdefined pure_counter
    @test @isdefined counter

    # smoke test
    @node T = 10 pure_counter()

    arr = Vector{Int}()
    # call node for 10 iterations
    @node T = 10 counter(arr)
    @test arr == cat(collect(1:5), collect(1:5), dims = 1)
end

@testset "nothing propagation" begin
    @node function f(arr)
        @init i = true
        i = !@prev(i)
        push!(arr, i)
    end
    arr = []
    @test (@node T = 2 f(arr); arr == [true, false])
end

@testset "mutable streams" begin
    @node function f(arr)
        @init m = [2, 2]
        m = [1, 2]
        m[1] = 2
        push!(arr, deepcopy(@prev(m)))
    end
    arr = []
    @node T = 2 f(arr)
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
    @node T = 5 f(arr)
    @test arr == vcat([0], collect(0:3))
end

@testset "reversed def & prev" begin
    @node function f(arr)
        @init y = 0
        y = @prev(y) + 1
        push!(arr, @prev(y))
    end
    arr = []
    @node T = 5 f(arr)
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
    @node T = 5 f(arr)
    @test arr == [0, 1, 1, 2]
end

@testset "ill-formed prev" begin
    @node function f()
        y = @prev(y) + 1
    end
    @test_throws MethodError (@node T = 2 f())
end

@testset "invalid argument" begin
    @node myparticularfunction(x::Bool) = x
    @test_throws MethodError (@node T = 1 myparticularfunction(0))
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
    @test_broken (@node T = 5 f(arr))
    @test_broken arr == collect(1:5)
end

@testset "side-effect init" begin
    @node function f(arr)
        @init x = (push!(arr, 0); 1)
    end
    arr = []
    @node T = 5 f(arr)
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
        return @node counter()
    end
    @node function f(arr)
        x = @node g()
        push!(arr, x)
    end

    arr = []
    @node T = 5 f(arr)
    @test arr == collect(1:5)
end
