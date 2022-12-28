using OnlineSampling.CD
import OnlineSampling.CD: condition_default, CdNormal

unmvnormal(d::MvNormal) = Normal(only(d.μ), (sqrt ∘ only)(d.Σ))

@testset "condition gaussian" begin
    lin = -5:5:0.45
    gen = -5:5:0.5
    pos = 0.5:10:0.5
    for (lc, μp, μc, σp, σc, vc) in Iterators.product(lin, gen, gen, pos, pos, gen)
        mvp = MvNormal([μp], [σp^2;;])
        mvc = CdMvNormal([lc;;], [μc], [σc^2;;])
        @test condition_default(mvp, mvc, [vc]) ≈ condition(mvp, mvc, [vc])

        p = Normal(μp, σp)
        c = CdNormal(lc, μc, σc)
        @test unmvnormal(mvc(mvp)) ≈ c(p)
        @test (unmvnormal ∘ condition)(mvp, mvc, [vc]) ≈ condition(p, c, vc)

        mvcond = condition_cd(mvp, mvc)
        cond = condition_cd(p, c)
        @test mvcond.linear[1] ≈ cond.linear
        @test mvcond.μ[1] ≈ cond.μ
        @test mvcond.Σ[1] ≈ (cond.σ)^2
    end
end
