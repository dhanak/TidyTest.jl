using TidyTest

macro m(expr)
    return Expr(:toplevel,
                :(module $(esc(gensym()))
                      using Main: @test_stdout
                      using Test, TidyTest
                      $(esc(expr))
                  end))
end

macro test_stdout(msg, expr)
    return quote
        mktemp() do path, io
            redirect_stdout(() -> $(esc(expr)), io)
            close(io)
            @test contains(read(path, String), $(esc(msg)))
        end
    end
end

@m @run_tests "pass" filters = ["pass"]
@m @run_tests "broken" filters = ["broken"]
@m @test_stdout "Failed" @test_throws TestSetException @run_tests "fail" filters = ["fail"]
@m @test_stdout "error()" @test_throws TestSetException @run_tests "error" filters = ["error"]
@m @test_stdout "Test Summary" @run_tests "verbose" filters = ["pass"] verbose = true
@m @run_tests "dir" filters = ["pass"] dir = "."
@m @run_tests "broken + pass" filters = ["broken", "pass"]
@m @test_stdout "Failed" @test_throws TestSetException @run_tests "fail + pass" filters = ["fail", "pass"]
@m @test_stdout r"error.*Failed"s @test_throws TestSetException @run_tests "all four"
