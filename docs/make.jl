using Documenter
using OnlineSampling

makedocs(
    sitename="OnlineSampling.jl",
    modules = [OnlineSampling],
    pages = [
        "Home" => "index.md",
        "Getting Started" => "start.md",
        "JuliaCon22" => "visu.md",
        "Library" => "library.md",
        "Internals" => "internals.md",
    ]
)

deploydocs(
    repo = "github.com/wazizian/OnlineSampling.jl.git",
)