using Documenter
using OnlineSampling

makedocs(
    sitename="OnlineSampling.jl",
    modules = [OnlineSampling],
    pages = [
        "Home" => "index.md",
        "Getting Started" => "start.md",
        "Library" => "library.md",
        "Internals" => "internals.md",
    ]
)