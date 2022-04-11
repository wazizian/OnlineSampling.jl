module SymbInterface

function initialize! end

function value! end

function rand! end

function observe! end

function dist! end

function dist end

struct RealizedObservation <: Exception end

function Base.showerror(io::IO, ::RealizedObservation)
    msg = """
          RealizedObservation exception:
          Invalid observe statement: trying to observe a realized symbolic variable
          """
    print(io, msg)
end

function get_node(gm, id) end

export initialize!, value!, rand!, observe!, RealizedObservation, dist

end
