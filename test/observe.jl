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

    lt = OnlineSampling.LinearTracker(
        DS.GraphicalModel(Int64),
        1,
        MvNormal(zeros(1), ScalMat(1, 1.0)),
    )
    @test OnlineSampling.unwrap_tracked_type(typeof(lt)) == Vector{Float64}
end

@testset "dummy obs" begin
    @node function f(obs)
        y = rand(Normal())
        @observe y obs
    end

    obs = [1.0, 2.0, 3.0]

    ir = OnlineSampling.@node_ir f(obs)
    @test OnlineSampling.is_node(ir)
    @test !OnlineSampling.is_reset_node(ir)

    @noderun T = 3 f(obs)
end

@testset "passed obs" begin
    @node function f()
        y = rand(Normal())
        return y
    end

    @node function g(y, obs)
        @observe y obs
    end

    @node function h(obs)
        y = @nodecall f()
        @nodecall g(y, obs)
    end

    obs = [1.0, 2.0, 3.0]

    @noderun T = 3 h(obs)
end

@testset "gaussian hmm" begin
    Σ = ScalMat(1, 1.0)
    @node function model()
        @init x = rand(MvNormal([0.0], Σ))
        x = rand(MvNormal(@prev(x), Σ))
        y = rand(MvNormal(x, Σ))
        return x, y
    end
    @node function hmm(obs)
        x, y = @nodecall model()
        @observe y obs
        return x
    end
    @node function main(obs)
        x = @nodecall hmm(obs)
    end

    obs = Vector{Float64}(1:5)
    obs = reshape(obs, (length(obs), 1))
    @assert size(obs) == (5, 1)

    @noderun T = 5 main(eachrow(obs))
end

@testset "invalid obs" begin
    @node function f(obs)
        y = rand(Normal())
        @observe (y * y) obs
    end
    obs = [1.0, 2.0, 3.0]

    @test_throws OnlineSampling.UntrackedObservation @noderun T = 3 f(obs)
end

@testset "invalid obs : atan" begin
    @node function f(obs)
        y = rand(IsoNormal(zeros(1), ScalMat(1, 1.0)))
        @observe atan.(y) obs
    end
    obs = [[1.0], [2.0], [3.0]]

    @test_throws OnlineSampling.UntrackedObservation @noderun T = 3 f(obs)
    @test_throws OnlineSampling.UntrackedObservation @noderun particles = 1 algo =
        delayed_sampling T = 3 f(obs)
    @test_throws OnlineSampling.UntrackedObservation @noderun particles = 1 algo =
        belief_propagation T = 3 f(obs)
end

@testset "invalid obs : atan bis" begin
    @node function f(obs)
        y = rand(IsoNormal(zeros(1), ScalMat(1, 1.0)))
        z = atan.(y)
        @observe y obs
        return z
    end
    obs = [[1.0], [2.0], [3.0]]

    @noderun T = 3 f(obs)
    @test_throws OnlineSampling.RealizedObservation @noderun particles = 1 algo =
        delayed_sampling T = 3 f(obs)
    @test_throws OnlineSampling.RealizedObservation @noderun particles = 1 algo =
        belief_propagation T = 3 f(obs)
end

@testset "invalid obs : collect (curr lim)" begin
    @node function f(obs)
        y = rand(IsoNormal(zeros(1), ScalMat(1, 1.0)))
        c = collect(y)
        @observe y obs
        return c
    end
    obs = [[1.0], [2.0], [3.0]]

    @noderun T = 3 f(obs)
    @test_throws OnlineSampling.RealizedObservation @noderun particles = 1 algo =
        delayed_sampling T = 3 f(obs)
    @test_throws OnlineSampling.RealizedObservation @noderun particles = 1 algo =
        belief_propagation T = 3 f(obs)
end

@testset "invalid obs : type (curr lim)" begin
    g(y::AbstractFloat) = y
    @node function f(obs)
        y = rand(Normal())
        @observe g(y) obs
    end
    obs = [1.0, 2.0, 3.0]

    @test_throws OnlineSampling.UntrackedObservation @noderun T = 3 f(obs)
end

@testset "bypass node signature (curr lim)" begin
    @node g(y::AbstractFloat) = y
    @node function f(obs)
        y = rand(Normal())
        @observe (@nodecall g(y)) obs
    end
    obs = [1.0, 2.0, 3.0]

    @test_throws OnlineSampling.UntrackedObservation @noderun T = 3 f(obs)
end

@testset "notinit with unsupported obs" begin
    function g(x::AbstractFloat, y)
        return x * y
    end
    @node function f()
        @init y = 0
        x = rand(Normal())
        y = g(x, @prev y)
    end

    @noderun T = 3 f()
end

const trans_test = [5.0]
const mult_test = 2.0 * I(1)
@testset "operations on trackedobs" begin
    x0 =
        OnlineSampling.TrackedObservation{Vector{Float64},Multivariate,Continuous,IsoNormal}(
            [5.1],
            MvNormal([10.0], ScalMat(1, 1.0)),
        )

    fun_test(z::typeof(x0)) = z + trans_test
    v_sum = OnlineSampling.irpass(fun_test, x0)
    @test v_sum == trans_test + OnlineSampling.value(x0)

    fun_test2(z::typeof(x0)) = mult_test * z
    v_mult = OnlineSampling.irpass(fun_test2, x0)
    @test v_mult == mult_test * OnlineSampling.value(x0)
end
