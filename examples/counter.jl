using OnlineSampling

@node function cpt()   # declare a stream processor
    @init x = 0        # initialize a memory x with value 0
    x = @prev(x) + 1   # at each step increment x
    println(x)
end

@node T = 10 cpt()     # unfold cpt for 10 steps
