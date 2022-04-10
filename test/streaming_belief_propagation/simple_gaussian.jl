using OnlineSampling.SBP
using OnlineSampling.CD

@testset "Observe parent" begin
    gm = SBP.GraphicalModel()

    x = initialize!(gm, MvNormal([0.0], ScalMat(1, 1.0)))

    y = initialize!(gm, CdMvNormal(3.0 * I(1), [1.0], ScalMat(1, 2.0)), x)

    observe!(gm, x, [1.0])

    x_node = SBP.get_node(x)
    y_node = SBP.get_node(y)

    @test x_node isa SBP.Realized
    @test x_node.val ≈ [1.0]
    @test y_node isa SBP.Initialized
    @test SBP.dist(gm, y) ≈ MvNormal([4.0], ScalMat(1, 2.0))
end

@testset "Observe child" begin
    gm = SBP.GraphicalModel()

    x = initialize!(gm, MvNormal([0.0], ScalMat(1, 1.0)))

    y = initialize!(gm, CdMvNormal(3.0 * I(1), [1.0], ScalMat(1, 2.0)), x)

    observe!(gm, y, [2.0])

    x_node = SBP.get_node(x)
    y_node = SBP.get_node(y)

    @test y_node isa SBP.Realized
    @test y_node.val ≈ [2.0]
    @test x_node isa SBP.Marginalized
    @test SBP.dist(gm, x) ≈ MvNormal([3 / 11], ScalMat(1, 2 / 11))
end

@testset "Child distribution" begin
    gm = SBP.GraphicalModel()

    x = initialize!(gm, MvNormal([0.0], ScalMat(1, 1.0)))

    y = initialize!(gm, CdMvNormal(3.0 * I(1), [1.0], ScalMat(1, 2.0)), x)

    d = SBP.dist(gm, y)
    @test d ≈ MvNormal([1.0], ScalMat(1, 11.0))
end

@testset "Sample child" begin
    gm = SBP.GraphicalModel()

    x = initialize!(gm, MvNormal([0.0], ScalMat(1, 1.0)))

    y = initialize!(gm, CdMvNormal(3.0 * I(1), [1.0], ScalMat(1, 2.0)), x)

    samples = [rand!(gm, y)[1] for _ = 1:100]

    test = OneSampleADTest(samples, Normal(1.0, sqrt(11.0)))
    @test pvalue(test) > 0.05
end
