@testset "dummy obs" begin
    _reset_node_mem_struct_types()
    @node function f(obs)
        y = Normal()
        @observe y obs
    end

    obs = [1.0, 2.0, 3.0]

    @node T = 3 f(obs)
end
