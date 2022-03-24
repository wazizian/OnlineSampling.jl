using OnlineSampling

function main()
    @node function cpt()
        @init x = 0
        x = @prev(x) + 1
        println(x)
    end

    @node T = 10 cpt()
end

main()
