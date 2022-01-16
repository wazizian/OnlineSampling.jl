@testset "smc counter" begin
    _reset_node_mem_struct_types()
    @node function counter()
        @init x = 0
        x = @prev(x) + 1
    end
    @node function test()
        det = @node counter()
        smc = @node particles = 100 counter()

        @test smc isa Cloud
        @test length(smc) == 100
        @test all(v -> v == det, smc)
    end

    @node T = 5 test()
end
