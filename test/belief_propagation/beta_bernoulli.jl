using OnlineSampling.BP
using OnlineSampling.CD

@testset "Observe parent" begin
    gm = BP.GraphicalModel(Int)

    x = initialize!(gm, Beta(1.0, 1.0))
    y = initialize!(gm, CdBernoulli(), x)
    observe!(gm, y, true)

    x_node = gm.nodes[x]
    y_node = gm.nodes[y]

    @test y_node isa BP.Realized
    @test y_node.val ≈ true
    @test x_node isa BP.Marginalized
    @test x_node.d ≈ Beta(2, 1)

    z = initialize!(gm, CdBernoulli(), x)
    observe!(gm, z, true)

    x_node = gm.nodes[x]
    z_node = gm.nodes[z]

    @test y_node isa BP.Realized
    @test y_node.val ≈ true
    @test x_node isa BP.Marginalized
    @test x_node.d ≈ Beta(3, 1)
end
