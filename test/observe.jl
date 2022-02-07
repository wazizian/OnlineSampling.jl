@testset "unwrap" begin
    y = OnlineSampling.internal_rand(OnlineSampling.SamplingCtx(), Normal())
    val = OnlineSampling.value(y)

    @test y isa OnlineSampling.TrackedObservation
    @assert val isa Float64

    @test OnlineSampling.unwrap_tracked_type(typeof(y)) == Float64
    @test OnlineSampling.unwrap_tracked_value(y) == val

    t = (0, y)
    @test OnlineSampling.unwrap_tracked_type(typeof(t)) == Tuple{Int64,Float64}
    @test OnlineSampling.unwrap_tracked_value(t) == (0, val)
end

@testset "dummy obs" begin
    _reset_node_mem_struct_types()
    @node function f(obs)
        y = rand(Normal())
        @observe y obs
    end

    obs = [1.0, 2.0, 3.0]

    ir = OnlineSampling.@node_ir f(obs)
    @test OnlineSampling.is_node(ir)
    @test !OnlineSampling.is_reset_node(ir)

    @node T = 3 f(obs)
end

@testset "passed obs" begin
    _reset_node_mem_struct_types()
    @node function f()
        y = rand(Normal())
        return y
    end

    @node function g(y, obs)
        @observe y obs
    end

    @node function h(obs)
        y = @node f()
        @node g(y, obs)
    end

    obs = [1.0, 2.0, 3.0]

    @node T = 3 h(obs)
end

@testset "invalid obs" begin
    _reset_node_mem_struct_types()
    @node function f(obs)
        y = rand(Normal())
        @observe (y * y) obs
    end
    obs = [1.0, 2.0, 3.0]

    @test_throws OnlineSampling.UntrackedObservation @node T = 3 f(obs)
end

@testset "invalid obs (curr lim)" begin
    _reset_node_mem_struct_types()
    g(y::AbstractFloat) = y
    @node function f(obs)
        y = rand(Normal())
        @observe g(y) obs
    end
    obs = [1.0, 2.0, 3.0]

    @test_throws OnlineSampling.UntrackedObservation @node T = 3 f(obs)
end

@testset "bypass node signature (curr lim)" begin
    _reset_node_mem_struct_types()
    @node g(y::AbstractFloat) = y
    @node function f(obs)
        y = rand(Normal())
        @observe (@node g(y)) obs
    end
    obs = [1.0, 2.0, 3.0]

    @test_throws OnlineSampling.UntrackedObservation @node T = 3 f(obs)
end

@testset "notinit with unsupported obs" begin
    _reset_node_mem_struct_types()
    function g(x::AbstractFloat, y)
        return x * y
    end
    @node function f()
        @init y = 0
        x = rand(Normal())
        y = g(x, @prev y)
    end

    @node T = 3 f()
end
