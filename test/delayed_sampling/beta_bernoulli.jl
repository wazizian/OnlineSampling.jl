using OnlineSampling.DS
using OnlineSampling.CD

@testset "Observe parent" begin
    gm = DS.GraphicalModel(Int)
    @test DS.is_inv_sat(gm)

    x = initialize!(gm, Beta(1.0, 1.0))
    @test DS.is_inv_sat(gm)

    y = initialize!(gm, CdBernoulli(), x)
    @test DS.is_inv_sat(gm)

    observe!(gm, y, true)
    @test DS.is_inv_sat(gm)

    x_node = gm.nodes[x]
    y_node = gm.nodes[y]

    @test y_node isa DS.Realized
    @test y_node.val ≈ true
    @test x_node isa DS.Marginalized
    @test x_node.d ≈ Beta(2, 1)

    z = initialize!(gm, CdBernoulli(), x)
    @test DS.is_inv_sat(gm)

    observe!(gm, z, true)
    @test DS.is_inv_sat(gm)

    x_node = gm.nodes[x]
    z_node = gm.nodes[z]

    @test y_node isa DS.Realized
    @test y_node.val ≈ true
    @test x_node isa DS.Marginalized
    @test x_node.d ≈ Beta(3, 1)
end
