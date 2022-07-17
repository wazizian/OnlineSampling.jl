using OnlineSampling.SBP
using OnlineSampling.CD

n = 10
m = 15

@testset "Observe child" begin
    gm = SBP.GraphicalModel()

    x = initialize!(gm, Beta(1.0, 1.0))
    y = initialize!(gm, CdBinomial(n), x)
    lpdf = observe!(gm, y, 4)
    x_node = SBP.get_node(x)
    y_node = SBP.get_node(y)

    @test y_node isa SBP.Realized
    @test y_node.val ≈ 4
    @test lpdf ≈ logpdf(BetaBinomial(n, 1.0, 1.0), 4)
    @test x_node isa SBP.Marginalized
    @test x_node.d ≈ Beta(5, 7)

    z = initialize!(gm, CdBinomial(m), x)
    lpdf = observe!(gm, z, 11)
    x_node = SBP.get_node(x)
    z_node = SBP.get_node(z)

    @test z_node isa SBP.Realized
    @test z_node.val ≈ 11
    @test lpdf ≈ logpdf(BetaBinomial(m, 5.0, 7.0), 11)
    @test x_node isa SBP.Marginalized
    @test x_node.d ≈ Beta(16, 11)
end

@testset "Observe parent then new child" begin
    gm = SBP.GraphicalModel()
    x = initialize!(gm, Beta(1.0, 1.0))
    y = initialize!(gm, CdBinomial(n), x)
    observe!(gm, x, 0.2)
    x_node = SBP.get_node(x)
    y_node = SBP.get_node(y)

    @test x_node isa SBP.Realized
    @test x_node.val ≈ 0.2
    @test y_node isa SBP.Initialized
    @test SBP.dist(y_node) ≈ Binomial(n, 0.2)

    z = initialize!(gm, CdBinomial(m), x)
    lpdf = observe!(gm, z, 11)
    y_node = SBP.get_node(y)
    z_node = SBP.get_node(z)

    @test z_node isa SBP.Realized
    @test lpdf ≈ logpdf(Binomial(m, 0.2), 11)
    @test SBP.dist(y_node) ≈ Binomial(n, 0.2)
end
