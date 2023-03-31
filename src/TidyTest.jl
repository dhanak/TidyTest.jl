module TidyTest

export @run_tests, SpinnerTestSet

using ProgressMeter: ProgressUnknown, finish!, next!

using Test # needed for @testset
using Test: AbstractTestSet, DefaultTestSet, Error, Fail, Result, get_testset

import Test: record, finish

struct SpinnerTestProgress
    pad::Int
    progress::ProgressUnknown
    results::Dict{Symbol, Int}

    function SpinnerTestProgress(pad::Integer)
        return new(pad, ProgressUnknown(spinner = true), Dict())
    end
end

struct SpinnerTestSet <: AbstractTestSet
    parent::Union{SpinnerTestSet, SpinnerTestProgress}
    wrapped::DefaultTestSet
    desc::AbstractString

    function SpinnerTestSet(desc::AbstractString;
                            width::Integer = displaysize(stderr)[2],
                            verbose::Bool = false,
                            kwargs...)
        parent = get_testset()
        if !(parent isa SpinnerTestSet)
            parent = SpinnerTestProgress(width - 25)
        end
        wrapped = DefaultTestSet(desc; verbose, kwargs...)
        return new(parent, wrapped, desc)
    end
end

function record(ts::SpinnerTestSet, res::T)::T where {T}
    update!(ts, res)
    record(ts.wrapped, res)
    return res
end

function finish(ts::SpinnerTestSet)::SpinnerTestSet
    if ts.parent isa SpinnerTestProgress
        finish(ts.parent)
    end
    if ts.parent isa SpinnerTestSet ||
        ts.wrapped.verbose ||
        !issubset(keys(ts.parent.results), [:Pass, :Broken])
        finish(ts.wrapped)
    end
    return ts
end

function finish(stp::SpinnerTestProgress)::Nothing
    success = keys(stp.results) ⊆ [:Pass, :Broken]
    finish!(stp.progress; spinner = success ? '✓' : '✗')
    return nothing
end

function update!(ts::SpinnerTestSet, res, children = [])::Nothing
    update!(ts.parent, res, [ts.desc; children])
    return nothing
end

function update!(stp::SpinnerTestProgress, res, parts)::Nothing
    if res isa Result
        n = nameof(typeof(res))
        stp.results[n] = get(stp.results, n, 0) + 1
    end
    stp.progress.color =
        haskey(stp.results, :Fail) || haskey(stp.results, :Error) ? :red :
        haskey(stp.results, :Broken) ? :yellow : :green
    if res isa Fail || res isa Error
        print(stderr, "\r\u1b[K") # clear progress line
    else
        stats = join(["$k: $v" for (k, v) in result_sort(stp.results)], " | ")
        desc = pad_trunc(join(parts, " / "), stp.pad - textwidth(stats) - 3)
        next!(stp.progress;
              desc = "$desc   $stats",
              spinner = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏")
    end
    return nothing
end

function result_sort(results::Dict{Symbol, Int})::Vector{Pair{Symbol, Int}}
    return sort!(collect(results);
                 by = v -> indexin(v, [:Pass, :Fail, :Error, :Broken])[1])
end

function pad_trunc(s::AbstractString, width::Int)::String
    return textwidth(s) > width ? "$(s[1:width - 1])…" : rpad(s, width)
end

macro run_tests(args...)
    kwargs = [Expr(:(=), arg.args[1], esc(arg.args[2]))
              for arg in args if Meta.isexpr(arg, :(=))]
    run_kwargs = filter(arg -> arg.args[1] ∈ [:filters, :dir], kwargs)
    ts_kwargs = setdiff(kwargs, run_kwargs)
    run_kwargs = map(arg -> Expr(:kw, arg.args...), run_kwargs)
    args = filter(arg -> !Meta.isexpr(arg, :(=)), [args...])
    name = isempty(args) ? project_name(string(__source__)) : only(args)
    return quote
        @testset SpinnerTestSet $(string(name)) $(ts_kwargs...) begin
            run_tests($__module__; $(run_kwargs...))
        end
    end
end

function project_name(test_source::AbstractString)::String
    return chopsuffix(splitpath(test_source)[end - 2], ".jl")
end

function run_tests(mod::Module; filters = ARGS, dir = ".")::Nothing
    smartcase = any(isuppercase, join(filters)) ? identity : lowercase
    filter(readdir(dir)) do file
        return isfile(file) &&
            endswith(file, ".jl") &&
            !startswith(file, ['.', '#']) &&
            file != "runtests.jl" &&
            (isempty(filters) || any(occursin(smartcase(file)), filters))
    end .|> mod.include
    return nothing
end

end # module TidyTest
