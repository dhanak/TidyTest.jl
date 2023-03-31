for i in 1:10
    @testset begin
        sleep(0.1)
        @test false
    end
end
