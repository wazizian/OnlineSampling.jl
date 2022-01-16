@testset "notinit edge cases" begin
    _reset_node_mem_struct_types()
    ip = OnlineSampling.IRPass(true)
    ip(println, OnlineSampling.notinit)
    @test ip(Base.iterate, [1.0], OnlineSampling.notinit) == OnlineSampling.notinit
    function f(x)
        y, z = x
        return z
    end
    @test ip(f, OnlineSampling.notinit) == OnlineSampling.notinit

    ip(
        println,
        OnlineSMC.Cloud{
            OnlineSampling.Particle{OnlineSampling.NotInit,OnlineSampling.DSOffCtx},
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

    @test !OnlineSampling.typeforces(
        OnlineSampling.NotInit,
        Union{OnlineSampling.NotInit,Int},
    )
    @test OnlineSampling.typeforces(OnlineSampling.NotInit, OnlineSampling.NotInit)
    @test !OnlineSampling.typeforces(OnlineSampling.NotInit, Vector{Any})
    @test OnlineSampling.typeforces(OnlineSampling.NotInit, Vector{OnlineSampling.NotInit})

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
    @test !OnlineSampling.typeforces(OnlineSampling.NotInit, B)
    @test OnlineSampling.typeforces(OnlineSampling.NotInit, C)

    @test OnlineSampling.hasnotinit((OnlineSampling.notinit, 1))
    @test !OnlineSampling.hasnotinit([1])
    @test OnlineSampling.hasnotinit(B(OnlineSampling.notinit))
    @test OnlineSampling.hasnotinit([1, OnlineSampling.notinit])
end

@testset "node marker" begin
    function f(x)::Int
        OnlineSampling.node_reset_marker()
        return x
    end
    ir = @code_ir f(0)

    @test OnlineSampling.is_node(ir)
    @test OnlineSampling.is_reset_node(ir)
    @test !OnlineSampling.is_node(ir; markers = (:node_no_reset_marker,))
end
