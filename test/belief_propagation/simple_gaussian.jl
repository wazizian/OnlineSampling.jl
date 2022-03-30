using OnlineSampling.BP
using OnlineSampling.BP: Marginalized, Initialized, Realized
using OnlineSampling.CD

@testset "Observe parent" begin
    gm = GraphicalModel(Int)
    @test is_inv_sat(gm)

    x = initialize!(gm, MvNormal([0.0], ScalMat(1, 1.0)))
    @test is_inv_sat(gm)

    y = initialize!(gm, CdMvNormal(3.0 * I(1), [1.0], ScalMat(1, 2.0)), x)
    @test is_inv_sat(gm)

    observe!(gm, x, [1.0])
    @test is_inv_sat(gm)

    x_node = gm.nodes[x]
    y_node = gm.nodes[y]

    @test x_node isa Realized
    @test x_node.val ≈ [1.0]
    @test y_node isa Marginalized
    @test y_node.d ≈ MvNormal([4.0], ScalMat(1, 2.0))
end

@testset "Observe child" begin
    gm = GraphicalModel(Int)
    @test is_inv_sat(gm)

    x = initialize!(gm, MvNormal([0.0], ScalMat(1, 1.0)))
    @test is_inv_sat(gm)

    y = initialize!(gm, CdMvNormal(3.0 * I(1), [1.0], ScalMat(1, 2.0)), x)
    @test is_inv_sat(gm)

    observe!(gm, y, [2.0])
    @test is_inv_sat(gm)

    x_node = gm.nodes[x]
    y_node = gm.nodes[y]

    @test y_node isa Realized
    @test y_node.val ≈ [2.0]
    @test x_node isa Marginalized
    @test x_node.d ≈ MvNormal([3 / 11], ScalMat(1, 2 / 11))
end

@testset "Child distribution" begin
    gm = GraphicalModel(Int)
    @test is_inv_sat(gm)

    x = initialize!(gm, MvNormal([0.0], ScalMat(1, 1.0)))
    @test is_inv_sat(gm)

    y = initialize!(gm, CdMvNormal(3.0 * I(1), [1.0], ScalMat(1, 2.0)), x)
    @test is_inv_sat(gm)

    d = dist!(gm, y)
    @test is_inv_sat(gm)
    @test d ≈ MvNormal([1.0], ScalMat(1, 11.0))
end

@testset "Sample child" begin
    gm = GraphicalModel(Int)
    @test is_inv_sat(gm)

    x = initialize!(gm, MvNormal([0.0], ScalMat(1, 1.0)))
    @test is_inv_sat(gm)

    y = initialize!(gm, CdMvNormal(3.0 * I(1), [1.0], ScalMat(1, 2.0)), x)
    @test is_inv_sat(gm)

    samples = [rand!(gm, y)[1] for _ = 1:100]
    @test is_inv_sat(gm)

    test = OneSampleADTest(samples, Normal(1.0, sqrt(11.0)))
    @test pvalue(test) > 0.05
end
