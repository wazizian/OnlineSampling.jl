@testset "Observe simple" begin
    gm = GraphicalModel(Int)
    @test is_inv_sat(gm)

    μ = [0.]
    Σ = ScalMat(1, 1.0)
    id = 1.0*I(1)

    gm, x1 = initialize!(gm, MvNormal(μ, Σ))
    @test is_inv_sat(gm)

    gm, x2 = initialize!(gm, CdMvNormal(id, μ, Σ), x1)
    @test is_inv_sat(gm)

    gm, x3 = initialize!(gm, CdMvNormal(id, μ, Σ), x1)
    @test is_inv_sat(gm)

    gm, x4 = initialize!(gm, CdMvNormal(id, μ, Σ), x2)
    @test is_inv_sat(gm)

    observe!(gm, x3, [1.])
    @test is_inv_sat(gm)

    x1_node = gm.nodes[x1]
    @test isnothing(x1_node.marginalized_child)
    @test x1_node isa Marginalized
    
    observe!(gm, x4, [1.])
    @test is_inv_sat(gm)

    nodes = map(i -> gm.nodes[i], [x1, x2, x3, x4])
    @test nodes[1] isa Marginalized
    @test nodes[2] isa Marginalized
    @test nodes[3] isa Realized
    @test nodes[4] isa Realized
end

@testset "Observe hard" begin
    gm = GraphicalModel(Int)
    @test is_inv_sat(gm)

    μ = [0.]
    Σ = ScalMat(1, 1.0)
    id = 1.0*I(1)

    gm, x1 = initialize!(gm, MvNormal(μ, Σ))
    @test is_inv_sat(gm)

    gm, x2 = initialize!(gm, CdMvNormal(id, μ, Σ), x1)
    @test is_inv_sat(gm)

    gm, x3 = initialize!(gm, CdMvNormal(id, μ, Σ), x1)
    @test is_inv_sat(gm)

    gm, x4 = initialize!(gm, CdMvNormal(id, μ, Σ), x2)
    @test is_inv_sat(gm)

    observe!(gm, x4, [1.])
    @test is_inv_sat(gm)

    x1_node = gm.nodes[x1]
    @test x1_node.marginalized_child == x2

    x2_node = gm.nodes[x2]
    @test isnothing(x2_node.marginalized_child)
    @test x2_node isa Marginalized
    
    observe!(gm, x3, [1.])
    @test is_inv_sat(gm)

    nodes = map(i -> gm.nodes[i], [x1, x2, x3, x4])
    @test nodes[1] isa Marginalized
    @test nodes[2] isa Realized
    @test nodes[3] isa Realized
    @test nodes[4] isa Realized
end