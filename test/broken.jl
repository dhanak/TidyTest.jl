for i in 1:10
    sleep(0.1)
    @test_broken false
end
