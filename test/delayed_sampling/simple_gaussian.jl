using OnlineSampling.DS
using OnlineSampling.CD

@testset "Observe parent" begin
    gm = DS.GraphicalModel(Int)
    @test DS.is_inv_sat(gm)

    x = initialize!(gm, MvNormal([0.0], ScalMat(1, 1.0)))
    @test DS.is_inv_sat(gm)

    y = initialize!(gm, CdMvNormal(3.0 * I(1), [1.0], ScalMat(1, 2.0)), x)
    @test DS.is_inv_sat(gm)

    observe!(gm, x, [1.0])
    @test DS.is_inv_sat(gm)

    x_node = gm.nodes[x]
    y_node = gm.nodes[y]

    @test x_node isa DS.Realized
    @test x_node.val ≈ [1.0]
    @test y_node isa DS.Marginalized
    @test y_node.d ≈ MvNormal([4.0], ScalMat(1, 2.0))
end

@testset "Observe child" begin
    gm = DS.GraphicalModel(Int)
    @test DS.is_inv_sat(gm)

    x = initialize!(gm, MvNormal([0.0], ScalMat(1, 1.0)))
    @test DS.is_inv_sat(gm)

    y = initialize!(gm, CdMvNormal(3.0 * I(1), [1.0], ScalMat(1, 2.0)), x)
    @test DS.is_inv_sat(gm)

    observe!(gm, y, [2.0])
    @test DS.is_inv_sat(gm)

    x_node = gm.nodes[x]
    y_node = gm.nodes[y]

    @test y_node isa DS.Realized
    @test y_node.val ≈ [2.0]
    @test x_node isa DS.Marginalized
    @test x_node.d ≈ MvNormal([3 / 11], ScalMat(1, 2 / 11))
end

@testset "Child distribution" begin
    gm = DS.GraphicalModel(Int)
    @test DS.is_inv_sat(gm)

    x = initialize!(gm, MvNormal([0.0], ScalMat(1, 1.0)))
    @test DS.is_inv_sat(gm)

    y = initialize!(gm, CdMvNormal(3.0 * I(1), [1.0], ScalMat(1, 2.0)), x)
    @test DS.is_inv_sat(gm)

    d = DS.dist!(gm, y)
    @test DS.is_inv_sat(gm)
    @test d ≈ MvNormal([1.0], ScalMat(1, 11.0))
end

@testset "Sample child" begin
    gm = DS.GraphicalModel(Int)
    @test DS.is_inv_sat(gm)

    x = initialize!(gm, MvNormal([0.0], ScalMat(1, 1.0)))
    @test DS.is_inv_sat(gm)

    y = initialize!(gm, CdMvNormal(3.0 * I(1), [1.0], ScalMat(1, 2.0)), x)
    @test DS.is_inv_sat(gm)

    samples = [rand!(gm, y)[1] for _ = 1:100]
    @test DS.is_inv_sat(gm)

    test = OneSampleADTest(samples, Normal(1.0, sqrt(11.0)))
    # Broken for now because repeated sampling is not correctly implemented yet
    @test pvalue(test) > 0.05
end

@testset "Observe with 3 children" begin
    gm = DS.GraphicalModel(Int)
    @test DS.is_inv_sat(gm)

    μ = [0.0]
    Σ = ScalMat(1, 1.0)
    id = 1.0 * I(1)

    x = initialize!(gm, MvNormal(μ, Σ))
    @test DS.is_inv_sat(gm)

    y = initialize!(gm, CdMvNormal(id, μ, Σ), x)
    @test DS.is_inv_sat(gm)

    z = initialize!(gm, CdMvNormal(id, μ, Σ), y)
    @test DS.is_inv_sat(gm)

    observe!(gm, z, [1.0])
    @test DS.is_inv_sat(gm)

    y_node = gm.nodes[y]
    @test y_node isa DS.Marginalized
    @test y_node.d ≈ MvNormal([2 / 3], 2 / 3 * I(1))

    d = DS.jointdist!(gm, y, x)
    @test d ≈ MvNormal([1, 2] / 3, [1 1; 1 2] - [1 2; 2 4] / 3)
end
