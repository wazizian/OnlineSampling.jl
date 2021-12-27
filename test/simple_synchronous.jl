@testset "counter" begin
    _reset_node_mem_struct_types()
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
    _reset_node_mem_struct_types()
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

    arr = Vector{Int}()

    # call node for 10 iterations
    @node T = 10 counter(arr)

    @test arr == cat(collect(1:5), collect(1:5), dims = 1)
end

@testset "nothing propagation" begin
    _reset_node_mem_struct_types()
    @node function f(arr)
        @init i = true
        i = !@prev(i)
        push!(arr, i)
    end
    arr = []
    @test (@node T = 2 f(arr); arr == [true, false])
end

@testset "mutable streams" begin
    _reset_node_mem_struct_types()
    @node function f(arr)
        @init m = [2, 2]
        m = [1, 2]
        m[1] = 2
        push!(arr, deepcopy(@prev(m)))
    end
    arr = []
    @node T = 2 f(arr)
    @test arr[2] == [2, 2]
end

@testset "delayed counter" begin
    _reset_node_mem_struct_types()
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

@testset "nothing edge cases" begin
    _reset_node_mem_struct_types()
    OnlineSampling.nothing_removal(println, nothing)
    OnlineSampling.nothing_removal(Base.iterate, [1.0], nothing)
end

@testset "reversed def & prev" begin
    _reset_node_mem_struct_types()
    @node function f(arr)
        @init y = 0
        y = @prev(y) + 1
        push!(arr, @prev(y))
    end
    arr = []
    @node T = 5 f(arr)
    @test arr[2:end] == collect(0:3)
end

@testset "pathological prev" begin
    _reset_node_mem_struct_types()
    @node function f(arr)
        @init x = 0
        @init y = 0
        y = @prev x
        x = ((a, b) -> (push!(arr, a); b))(y, (@prev y) + 1)
        @test !isnothing(x)
    end
    arr = []
    @node T = 5 f(arr)
    @test arr == [0, 0, 1, 1, 2]
end

@testset "one line counter" begin
    _reset_node_mem_struct_types()
    @node function f(arr)
        x = (@prev x) + (@init x = 1)
        push!(arr, x)
    end
    arr = []
    @node T = 5 f(arr)
    @test arr == collect(1:5)
end

@testset "side-effect init" begin
    _reset_node_mem_struct_types()
    @node function f(arr)
        @init x = (push!(arr, 0); 1)
    end
    arr = []
    @node T = 5 f(arr)
    # not sure this is the right design decision
    @test arr == fill(0, 5)
end
