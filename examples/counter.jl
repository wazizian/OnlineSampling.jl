using OnlineSampling

@node function cpt()   # declare a stream processor
    @init x = 0        # initialize a memory x with value 0
    x = @prev(x) + 1   # at each step increment x
    return x           # return the current value
end

for x in @nodeiter T = 10 cpt() # for 10 iterations of cpt
    println(x)                  # print the current value
end
