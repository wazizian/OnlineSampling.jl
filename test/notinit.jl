@testset "notinit edge cases" begin
    ip = OnlineSampling.irpass
    reset_println(args...) = (OnlineSampling.node_no_reset_marker(); println(args...))
    ip(reset_println, OnlineSampling.notinit)
    function g()
        OnlineSampling.node_reset_marker()
        return Base.iterate([1.0], OnlineSampling.notinit)
    end
    @test ip(g) == OnlineSampling.notinit
    function f()
        OnlineSampling.node_reset_marker()
        x = OnlineSampling.notinit
        y, z = x
        return z
    end
    @test ip(f) == OnlineSampling.notinit

    ip(
        reset_println,
        OnlineSMC.Cloud{
            OnlineSampling.MemParticle{
                OnlineSampling.NotInit,
                OnlineSampling.OffCtx,
                OnlineSampling.NotInit,
            },
        }(
            2,
        ),
    )
end

@testset "hasnotinit" begin
    @test OnlineSampling.typeallows(
        OnlineSampling.NotInit,
        Union{OnlineSampling.NotInit,Int},
    )
    @test OnlineSampling.typeallows(OnlineSampling.NotInit, Any)
    @test !OnlineSampling.typeallows(OnlineSampling.NotInit, Int)
    @test OnlineSampling.typeallows(OnlineSampling.NotInit, Vector{Any})
    @test !OnlineSampling.typeallows(OnlineSampling.NotInit, Vector{Int})
    @test OnlineSampling.typeallows(
        OnlineSampling.NotInit,
        Tuple{OnlineSampling.NotInit,Int},
    )

    struct A
        x::Int
    end
    struct B
        x::Any
    end
    struct C
        x::OnlineSampling.NotInit
    end
    @test !OnlineSampling.typeallows(OnlineSampling.NotInit, A)
    @test OnlineSampling.typeallows(OnlineSampling.NotInit, B)
end

@testset "node marker" begin
    function f(x)::Int
        OnlineSampling.node_reset_marker()
        return x
    end
    ir = @code_ir f(0)

    @test !OnlineSampling.is_node(ir)
    @test OnlineSampling.is_reset_node(ir)
    @test !OnlineSampling.is_node(ir; markers = (:node_no_reset_marker,))
end
