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
end

@testset "hasnotinit" begin
    @test OnlineSampling.typeallowsnotinit(Union{OnlineSampling.NotInit,Int})
    @test OnlineSampling.typeallowsnotinit(Any)
    @test !OnlineSampling.typeallowsnotinit(Int)
    @test OnlineSampling.typeallowsnotinit(Vector{Any})
    @test !OnlineSampling.typeallowsnotinit(Vector{Int})
    @test OnlineSampling.typeallowsnotinit(Tuple{OnlineSampling.NotInit,Int})

    @test !OnlineSampling.typeforcesnotinit(Union{OnlineSampling.NotInit,Int})
    @test OnlineSampling.typeforcesnotinit(OnlineSampling.NotInit)
    @test !OnlineSampling.typeforcesnotinit(Vector{Any})
    @test OnlineSampling.typeforcesnotinit(Vector{OnlineSampling.NotInit})

    struct A
        x::Int
    end
    struct B
        x::Any
    end
    struct C
        x::OnlineSampling.NotInit
    end
    @test !OnlineSampling.typeallowsnotinit(A)
    @test OnlineSampling.typeallowsnotinit(B)
    @test !OnlineSampling.typeforcesnotinit(B)
    @test OnlineSampling.typeforcesnotinit(C)

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
    @test !OnlineSampling.is_node(ir; markers=(:node_no_reset_marker,))
end
