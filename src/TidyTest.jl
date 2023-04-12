module TidyTest

using Reexport: @reexport
using ProgressMeter: ProgressUnknown, finish!, next!
using Test: AbstractTestSet, DefaultTestSet, Error, Fail, Result, get_testset

import Test: record, finish

@reexport using Test
export @run_tests, SpinnerTestSet

struct SpinnerTestProgress
    pad::Int
    progress::ProgressUnknown
    results::Dict{Symbol, Int}

    function SpinnerTestProgress(pad::Integer)
        return new(pad, ProgressUnknown(spinner = true), Dict())
    end
end

"""
    SpinnerTestSet(desc::String; [width::Integer, verbose::Bool, rest...])

An implementation of `Test.AbstractTestSet`, that reports testing progress using
`ProgressMeter.ProgressUnknown`, continuously updating the status as tests are
completed.

Arguments:

* `desc`: the name of the testset;

* `width`: the display width of the progress line (defaults to the width of the
  terminal);

* `verbose`: whether to print a detailed summary even when none of the tests
  fail or throw an error (defaults to `false`);

* all other keyword arguments are passed directly to `Test.DefaultTestSet`.
"""
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
        print(stdout, "\r\u1b[K") # clear progress line
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

"""
    @run_tests [name] [dir="."] [filters=ARGS] [rest...]

Discover and include (Julia) test files from the directory of the caller, and
wrap them in a [`SpinnerTestSet`](@ref) for reporting. The name of the testset
is automatically derived from the package name if the macro is called from the
`runtests.jl` file.

Optional arguments:

* `name`: explicitly name the testset;

* `dir=path`: discover tests in the provided directory (defaults to the
  directory of the source file that contains the macro call);

* `filters=[...]`: filter discovered source files - include only files with a
  name which contains any of the filter strings as a substring (defaults to the
  command line arguments);

* all other keyword arguments are passed directly to [`SpinnerTestSet`](@ref).

Filtering uses smart case matching: if any of the patterns contains at least one
capital letter, then matching is case-sensitive, otherwise it is
case-insensitive.

# Example

A minimalistic `runtests.jl` file:

```julia
using TidyTest

@run_tests
```
"""
macro run_tests(args...)
    self = let f = __source__.file
        f !== nothing && isfile(string(f)) ? string(f) : abspath("runtests.jl")
    end
    kwargs = [Expr(:(=), arg.args[1], esc(arg.args[2]))
              for arg in args if Meta.isexpr(arg, :(=))]
    run_kwargs = filter(arg -> arg.args[1] ∈ [:filters, :dir], kwargs)
    ts_kwargs = setdiff(kwargs, run_kwargs)
    run_kwargs = map(arg -> Expr(:kw, arg.args...), run_kwargs)
    args = filter(arg -> !Meta.isexpr(arg, :(=)), [args...])
    name = isempty(args) ? project_name(self) : only(args)
    return quote
        @testset SpinnerTestSet $(string(name)) $(ts_kwargs...) begin
            run_tests($__module__; self = $self, $(run_kwargs...))
        end
    end
end

function project_name(test_source::AbstractString)::String
    parts = splitpath(test_source)
    return if length(parts) >= 3 && parts[end - 1] ∈ ["src", "test"]
        replace(parts[end - 2], r"\.jl$" => "")
    else
        "Running tests"
    end
end

function run_tests(mod::Module;
                   filters::AbstractVector{<: AbstractString} = ARGS,
                   self::AbstractString = "runtests.jl",
                   dir::AbstractString = dirname(self),
                  )::Nothing
    smartcase = any(isuppercase, join(filters)) ? identity : lowercase
    filter(readdir(dir)) do file
        return isfile(file) &&
            endswith(file, ".jl") &&
            !startswith(file, ['.', '#']) &&
            file != basename(self) &&
            (isempty(filters) || any(occursin(smartcase(file)), filters))
    end .|> mod.include
    return nothing
end

end # module TidyTest
