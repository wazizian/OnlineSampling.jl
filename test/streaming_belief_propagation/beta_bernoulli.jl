using OnlineSampling.SBP
using OnlineSampling.CD

@testset "Observe child" begin
    gm = SBP.GraphicalModel()

    x = initialize!(gm, Beta(1.0, 1.0))
    y = initialize!(gm, CdBernoulli(), x)
    observe!(gm, y, true)

    x_node = SBP.get_node(x)
    y_node = SBP.get_node(y)

    @test y_node isa SBP.Realized
    @test y_node.val ≈ true
    @test x_node isa SBP.Marginalized
    @test x_node.d ≈ Beta(2, 1)

    z = initialize!(gm, CdBernoulli(), x)
    observe!(gm, z, true)

    x_node = SBP.get_node(x)
    z_node = SBP.get_node(z)

    @test z_node isa SBP.Realized
    @test z_node.val ≈ true
    @test x_node isa SBP.Marginalized
    @test x_node.d ≈ Beta(3, 1)
end

@testset "Observe parent then new child" begin
    gm = SBP.GraphicalModel()

    x = initialize!(gm, Beta(1.0, 1.0))
    y = initialize!(gm, CdBernoulli(), x)
    observe!(gm, x, 0.2)

    x_node = SBP.get_node(x) 
    y_node = SBP.get_node(y) 

    @test x_node isa SBP.Realized
    @test x_node.val ≈ 0.2
    @test y_node isa SBP.Initialized
    @test SBP.dist(y_node) ≈ Bernoulli(0.2)

    z = initialize!(gm, CdBernoulli(), x)
    logp = observe!(gm, z, true)

    y_node = SBP.get_node(y)
    z_node = SBP.get_node(z) 

    @test z_node isa SBP.Realized
    @test logp ≈ log(0.2)
    @test SBP.dist(y_node) ≈ Bernoulli(0.2)
end