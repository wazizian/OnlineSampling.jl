module visu

include("basics_plane.jl")
include("utmb.jl")

using Pkg

function __init__()
    #stuff to do at startup
    isfile("visu/Manifest.toml") || Pkg.instantiate()
end

end # module
