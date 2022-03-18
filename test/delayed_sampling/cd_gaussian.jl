unmvnormal(d::MvNormal) = Normal(only(d.μ), (sqrt ∘ only)(d.Σ))

@testset "condition gaussian" begin
    lin = -5:5:0.45
    gen = -5:5:0.5
    pos = 0.5:10:0.5
    for (lc, μp, μc, σp, σc, vc) in Iterators.product(lin, gen, gen, pos, pos, gen)
        mvp = MvNormal([μp], [σp^2;;])
        mvc = DelayedSampling.CdMvNormal([lc;;], [μc], [σc^2;;])
        @test DelayedSampling.condition_default(mvp, mvc, [vc]) ≈
              DelayedSampling.condition(mvp, mvc, [vc])

        p = Normal(μp, σp)
        c = DelayedSampling.CdNormal(lc, μc, σc)
        @test unmvnormal(mvc(mvp)) ≈ c(p)
        @test (unmvnormal ∘ DelayedSampling.condition)(mvp, mvc, [vc]) ≈
              DelayedSampling.condition(p, c, vc)
    end
end
