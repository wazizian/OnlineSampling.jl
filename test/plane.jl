@testset "plane" begin
    # example from https://youtu.be/aUkBa1zMKv4
    ground(x) =
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


    Nparticules = 500
    Nsamples = 500
    T = 10

    # Some unceratinty parameters
    measurementNoiseStdev = 0.1 * I(1);
    speedStdev = 0.2 * I(1);

    # Speed of the aircraft
    speed = [0.2];
    # Set starting position of aircraft
    planePosX = [-25];
    planePosY = [4];

    @node function true_plane()
        @init x = planePosX
        x = @prev(x) + speed
        h = planePosY .- ground.(x)
        return x, h
    end

    traj = collect(@nodeiter T = T true_plane())
    obs = [t[2] for t in traj]

    @node function model()
        @init x = rand(MvNormal([0.0], 15.0*I(1)))
        x = rand(MvNormal(@prev(x) + speed, speedStdev^2))
        h = rand(MvNormal(planePosY .- ground.(x), measurementNoiseStdev^2))
        return x, h
    end

    @node function infer(obs)
        x, h = @nodecall model()
        @observe(h, obs)
        return x
    end

    @node function model1d()
        @init x = rand(Normal(0.0, 15.0))
        x = rand(Normal(@prev(x) + speed[1], speedStdev[1,1]))
        h = rand(Normal(planePosY[1] - ground(x), measurementNoiseStdev[1,1]))
        return x, h
    end

    @node function infer1d(obs)
        x, h = @nodecall model1d()
        @observe(h, obs)
        return x
    end

    cloud = @noderun particles = N infer(obs)
    cloud1d = @noderun particles = N infer1d(obs)

    samples = dropdims(rand(cloud, Nsamples); dims=1)
    samples1d = vec(rand(cloud1d, Nsamples))

    test = KSampleADTest(samples, samples1d)
    @test (pvalue(test) > 0.01) || @show test
end
