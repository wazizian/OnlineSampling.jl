@testset "counter" begin
    @node function counter(arr)
        @init i = 1
        i = (@prev i) + 1
        push!(arr, i)
    end

    @test @isdefined counter
    
    arr = Vector{Int}()

    # call node for 10 iterations
    @node T=10 counter(arr)

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
        i = @node pure_counter()
        push!(arr, i)
    end

    @test @isdefined pure_counter
    @test @isdefined counter
    
    arr = Vector{Int}()

    # call node for 10 iterations
    @node T=10 counter(arr)

    @test arr == collect(1:10)
end

@testset "nothing propagation" begin
    @node function f(arr)
        @init i = true
        i = !@prev(i)
        push!(arr, i)
    end
    arr = []
    @test_broken (@node T=2 f(arr); arr == [true, false])
end

@testset "mutable streams" begin
    @node function f(arr)
        @init m = [2, 2]
        m = [1, 2]
        m[1] = 2
        push!(arr, deepcopy(@prev(m)))
    end
    arr = []
    @node T=2 f(arr)
    @test arr[2] == [2, 2]
end


