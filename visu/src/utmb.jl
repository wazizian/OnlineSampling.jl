#include("basics_plane.jl")
include("utmb-data.jl")

#plot(alt_utmb)
small_alt_utmb = visu.alt_utmb[1:120:end]
export small_alt_utmb

function x_pos_utmb(x,alt_utmb=alt_utmb)
    Int(mod1(round(x),length(alt_utmb)))
end
export x_pos_utmb

function polar_x_pos(x,alt_utmb=alt_utmb)
    x_pos_utmb(x,alt_utmb)*2*π/length(alt_utmb)
end
export polar_x_pos

function delta(x1,x2,alt_utmb=alt_utmb)
    xpos1 = x_pos_utmb(x1,alt_utmb)
    xpos2 = x_pos_utmb(x2,alt_utmb)
    return minimum([abs(xpos1-xpos2), abs(xpos2+length(alt_utmb)-xpos1), abs(xpos1+length(alt_utmb)-xpos2)])
end
export delta

function ground_utmb(x, alt_utmb=alt_utmb)
    alt_utmb[x_pos_utmb(x,alt_utmb)]/maximum(alt_utmb)
end
export ground_utmb

plotx_utmb = range(1,length(alt_utmb))
export plotx_utmb

startPosX = [1]
export startPosX
startPosY = [alt_utmb[1]]
export startPosY
x_min = 0.0
export x_min
y_max = 3.0
export y_max

measurementNoiseStdev = 1/maximum(alt_utmb)
export measurementNoiseStdev