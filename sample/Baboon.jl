@testset "Baboon" begin
    for i in 1:10
        @test sleep(rand() / 2) == nothing
    end
end
