using OnlineSampling.BP
using OnlineSampling.CD

@testset "Observe child" begin
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

@testset "Observe parent then new child" begin
    gm = BP.GraphicalModel(Int)

    x = initialize!(gm, Beta(1.0, 1.0))
    y = initialize!(gm, CdBernoulli(), x)
    observe!(gm, x, 0.2)

    x_node = gm.nodes[x]
    y_node = gm.nodes[y]

    @test x_node isa BP.Realized
    @test x_node.val ≈ 0.2
    @test y_node isa BP.Initialized
    @test BP.dist(gm, y_node) ≈ Bernoulli(0.2)

    z = initialize!(gm, CdBernoulli(), x)
    logp = observe!(gm, z, true)
    z_node = gm.nodes[z]

    @test z_node isa BP.Realized
    @test logp ≈ log(0.2)
    @test BP.dist(gm, y_node) ≈ Bernoulli(0.2)
end
