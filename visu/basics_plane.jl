using OnlineSampling
using PDMats
using Distributions
using LinearAlgebra
using Pkg
Pkg.activate("./visu/")
using Plots

# example from https://youtu.be/aUkBa1zMKv4
ground_sym(x) =
    (x >= 10) .* (
        (1 - (x - 10) / 30) .* sin(x - 10) +
        ((x - 10) / 30) .* sin(1.5 * (x - 10)) +
        0.2 .* (x - 10) .* (x <= 20) +
        2 * (x > 20)
    ) +
    (x <= -10) .* (
        (1 - (-x - 10) / 30) .* sin(-x - 10) +
        ((-x - 10) / 30) .* sin(1.5 * (-x - 10)) +
        0.2 .* (-x - 10) .* (x >= -20) +
        2 * (x < -20) 
    )
    
ground_asym(x) =
    (x >= 10) .* (
        (1 - (x - 10) / 30) .* sin(x - 10) +
        ((x - 10) / 30) .* sin(1.5 * (x - 10)) +
        0.2 .* (x - 10) .* (x <= 20) +
        (2+ 0.05 .*(x-20)) * (x > 20) 
    ) +
    (x <= -10) .* (
        (1 - (-x - 10) / 30) .* sin(-x - 10) +
        ((-x - 10) / 30) .* sin(1.5 * (-x - 10)) +
        0.2 .* (-x - 10) .* (x >= -20) +
        2 * (x < -20)
    ) -
    (x>=30) .* (x-30)/15

x_min = -40
x_max = 60
plotx = collect(x_min:0.01:x_max)
plot(plotx, ground_asym.(plotx))

# Set starting position of aircraft
planePosX = [-35];
planePosY = [4];
measurementNoiseStdev = 0.1
speedStdev = 0.2

softmax(x) = exp.(x .- maximum(x)) ./ sum(exp.(x .- maximum(x)))

"""
    input: cloud
    output: values of the particles and associated proba
"""
function particles_prob(cloud)
    values = [c.retvalue[1][1] for c in cloud.particles]
    permut = sortperm(values)
    return values[permut], softmax(cloud.logweights[permut])
end