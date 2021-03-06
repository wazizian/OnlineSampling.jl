using OnlineSampling.DS
using OnlineSampling.CD

@testset "Observe simple" begin
    gm = DS.GraphicalModel(Int)
    @test DS.is_inv_sat(gm)

    μ = [0.0]
    Σ = ScalMat(1, 1.0)
    id = 1.0 * I(1)

    x1 = initialize!(gm, MvNormal(μ, Σ))
    @test DS.is_inv_sat(gm)

    x2 = initialize!(gm, CdMvNormal(id, μ, Σ), x1)
    @test DS.is_inv_sat(gm)

    x3 = initialize!(gm, CdMvNormal(id, μ, Σ), x1)
    @test DS.is_inv_sat(gm)

    x4 = initialize!(gm, CdMvNormal(id, μ, Σ), x2)
    @test DS.is_inv_sat(gm)

    observe!(gm, x3, [1.0])
    @test DS.is_inv_sat(gm)

    x1_node = gm.nodes[x1]
    @test isnothing(x1_node.marginalized_child)
    @test x1_node isa DS.Marginalized

    observe!(gm, x4, [1.0])
    @test DS.is_inv_sat(gm)

    nodes = map(i -> gm.nodes[i], [x1, x2, x3, x4])
    @test nodes[1] isa DS.Marginalized
    @test nodes[2] isa DS.Marginalized
    @test nodes[3] isa DS.Realized
    @test nodes[4] isa DS.Realized
end

@testset "Observe hard" begin
    gm = DS.GraphicalModel(Int)
    @test DS.is_inv_sat(gm)

    μ = [0.0]
    Σ = ScalMat(1, 1.0)
    id = 1.0 * I(1)

    x1 = initialize!(gm, MvNormal(μ, Σ))
    @test DS.is_inv_sat(gm)

    x2 = initialize!(gm, CdMvNormal(id, μ, Σ), x1)
    @test DS.is_inv_sat(gm)

    x3 = initialize!(gm, CdMvNormal(id, μ, Σ), x1)
    @test DS.is_inv_sat(gm)

    x4 = initialize!(gm, CdMvNormal(id, μ, Σ), x2)
    @test DS.is_inv_sat(gm)

    observe!(gm, x4, [1.0])
    @test DS.is_inv_sat(gm)

    x1_node = gm.nodes[x1]
    @test x1_node.marginalized_child == x2

    x2_node = gm.nodes[x2]
    @test isnothing(x2_node.marginalized_child)
    @test x2_node isa DS.Marginalized

    observe!(gm, x3, [1.0])
    @test DS.is_inv_sat(gm)

    nodes = map(i -> gm.nodes[i], [x1, x2, x3, x4])
    @test nodes[1] isa DS.Marginalized
    @test nodes[2] isa DS.Realized
    @test nodes[3] isa DS.Realized
    @test nodes[4] isa DS.Realized
end

@testset "Buggy example" begin
    gm = DS.GraphicalModel(Int)
    μ = [0.0]
    Σ = ScalMat(1, 1.0)
    id = 1.0 * I(1)
    x1 = initialize!(gm, MvNormal(μ, Σ))
    x2 = initialize!(gm, CdMvNormal(id, μ, Σ), x1)
    x3 = initialize!(gm, CdMvNormal(id, μ, Σ), x1)
    x4 = initialize!(gm, CdMvNormal(id, μ, Σ), x2)
    x5 = initialize!(gm, CdMvNormal(id, μ, Σ), x2)

    observe!(gm, x4, [1.0])
    observe!(gm, x3, [1.0])

    x2_node = gm.nodes[x2]
    x5_node = gm.nodes[x5]

    @test x2_node isa DS.Realized
    @test x5_node isa DS.Marginalized

    d = x5_node.d
    @test d.μ ≈ x2_node.val
end
