@testset "Racoon" begin
    for i in 1:20
        @test_nowarn sleep(rand() / 2)
    end

    @testset "Rocky" for i in 1:20
        @test sleep(rand() / 2) === nothing
    end
end
