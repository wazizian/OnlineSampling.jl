using OnlineSampling.SBP
using OnlineSampling.CD
using PDMats
using OnlineSampling: track_rv

@testset "Tracker SBP" begin
    mean_vec = [0.0, 1.0]
    var_vec = ScalMat(2, 1.0)
    trans_mat  = [1.0 0.0; 1.0 1.0]
    var_vec2 = X_A_Xt(var_vec, inv(trans_mat))

    gm = SBP.GraphicalModel()
    x = initialize!(gm, MvNormal(mean_vec, var_vec))
    y = initialize!(gm, CdMvNormal(trans_mat, mean_vec, var_vec), x)

    gm_trv = SBP.GraphicalModel()
    lt_x = track_rv(gm_trv, MvNormal(mean_vec, var_vec))
    lt_z = track_rv(gm_trv, (CdMvNormal(I(2), [0.0,0.0],var_vec2), lt_x.id))
    lt_y = trans_mat * lt_z + mean_vec

    @test dist(lt_y) ≈ SBP.dist(gm,y)
    
end
