#include("basics_plane.jl")
include("utmb-data.jl")

#plot(alt_utmb)
small_alt_utmb = visu.alt_utmb[1:120:end]
export small_alt_utmb

function x_pos_utmb(x,alt_utmb=alt_utmb)
    Int(mod1(round(x),length(alt_utmb)))
end
export x_pos_utmb

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

function reflectup(vect,t)
    ind = vect .> t
    d = vect .* ind .- t * ind
    return vect- 2*d
end

reflectdown(vect,t) = -reflectup(-vect, -t)

function reflectupd(vect,u,d)
    new_vect = vect
    for i=2:length(vect)
        if (new_vect[i] > u)
            #println(i,"utmb.jl")
            new_vect[i-1:end] = reflectup(new_vect[i-1:end], u)
        elseif (new_vect[i] < d)
            #println(i,"d")
            new_vect[i-1:end] = reflectdown(new_vect[i-1:end], d)
        end
    end
    return new_vect
end
export reflectupd