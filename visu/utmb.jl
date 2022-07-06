#include("basics_plane.jl")
include("utmb-data.jl")

#plot(alt_utmb)

function x_pos_utmb(x)
    Int(mod1(round(x),length(alt_utmb)))
end

function delta(x1,x2)
    xpos1 = x_pos_utmb(x1)
    xpos2 = x_pos_utmb(x2)
    return minimum([abs(xpos1-xpos2), abs(xpos2+length(alt_utmb)-xpos1), abs(xpos1+length(alt_utmb)-xpos2)])
end

function ground_utmb(x)
    alt_utmb[x_pos_utmb(x)]/maximum(alt_utmb)
end

plotx_utmb = range(1,length(alt_utmb))

startPosX = [1]
startPosY = [alt_utmb[1]]
x_min = 0.0
y_max = 3.0

measurementNoiseStdev = 1/maximum(alt_utmb)
