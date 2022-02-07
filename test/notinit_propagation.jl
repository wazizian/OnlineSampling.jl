@testset "isnotinit" begin
    e = :(Base.getproperty(OnlineSampling, :notinit))
    @test OnlineSampling.isnotinit(Set{OnlineSampling.Variable}(), e)
end


@testset "addition" begin
    function f(x)
        y = OnlineSampling.notinit
        return x + y
    end
    ir = @code_ir f(1)
    ir = OnlineSampling.propagate_notinits!(ir)
    @test IRTools.evalir(ir, nothing, 1) === OnlineSampling.notinit
end

@testset "getproperty" begin
    function f(x)
        y = Base.getproperty(OnlineSampling, :notinit)
        return x + y
    end
    ir = @code_ir f(1)
    ir = OnlineSampling.propagate_notinits!(ir)
    @test IRTools.evalir(ir, nothing, 1) === OnlineSampling.notinit
end

@testset "while loop" begin
    function f()
        y = OnlineSampling.notinit
        i = 1
        x = 0
        while i > 0
            x = y + i
            i -= 1
        end
        return x
    end
    ir = @code_ir f()
    ir = OnlineSampling.propagate_notinits!(ir)
    @test IRTools.evalir(ir, nothing) === OnlineSampling.notinit
end

@testset "while loop with notinit" begin
    function f()
        y = OnlineSampling.notinit
        x = 0
        while y > 0
            y -= 1
        end
        return x
    end
    ir = @code_ir f()
    ir = OnlineSampling.propagate_notinits!(ir)
    @test IRTools.evalir(ir, nothing) == 0
end
