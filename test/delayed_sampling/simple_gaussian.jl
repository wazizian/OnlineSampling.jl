using OnlineSampling.DS

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
    @test y_node.d ≈ MvNormal([1.0], ScalMat(1, 11.0))
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
    # Broken for now because repeated sampling is not correctly implemented yet
    @test pvalue(test) > 0.05
end

@testset "Observe with 3 children" begin
    gm = GraphicalModel(Int)
    @test is_inv_sat(gm)

    μ = [0.0]
    Σ = ScalMat(1, 1.0)
    id = 1.0 * I(1)

    x = initialize!(gm, MvNormal(μ, Σ))
    @test is_inv_sat(gm)

    y = initialize!(gm, CdMvNormal(id, μ, Σ), x)
    @test is_inv_sat(gm)

    z = initialize!(gm, CdMvNormal(id, μ, Σ), y)
    @test is_inv_sat(gm)

    observe!(gm, z, [1.0])
    @test is_inv_sat(gm)

    y_node = gm.nodes[y]
    @test y_node isa Marginalized
    @test y_node.d ≈ MvNormal([2 / 3], 2 / 3 * I(1))

    d = jointdist!(gm, y, x)
    @test d ≈ MvNormal([1, 2] / 3, [1 1; 1 2] - [1 2; 2 4] / 3)
end
