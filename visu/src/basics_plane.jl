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
export ground_sym

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
export ground_asym

x_min = -40
export x_min
x_max = 60
export x_max
plotx = collect(x_min:0.01:x_max)
export plotx
#plot(plotx, ground_asym.(plotx))

# Set starting position of aircraft
planePosX = [-35]
export planePosX
planePosY = [4];
export planePosY
measurementNoiseStdev = 0.1
export measurementNoiseStdev
speedStdev = 0.2
export speedStdev

softmax(x) = exp.(x .- maximum(x)) ./ sum(exp.(x .- maximum(x)))
export softmax

"""
    input: cloud
    output: values of the particles and associated proba
"""
function particles_prob(cloud)
    values = [c.retvalue[1][1] for c in cloud.particles]
    permut = sortperm(values)
    return values[permut], softmax(cloud.logweights[permut])
end
export particles_prob