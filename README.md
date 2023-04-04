[![CI](https://github.com/dhanak/TidyTest.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/dhanak/TidyTest.jl/actions/workflows/CI.yml)

# TidyTest.jl

An `AbstractTestSet` implementation and a helper macro for test execution with
auto discovery and a neater test summary.

## Installation

Within Julia, execute

```julia
using Pkg; Pkg.add("TidyTest")
```

## Usage

For the simplest use case, write the following lines in your `runtests.jl` file:

```julia
using TidyTest

@run_tests
```

Add `TidyTest.jl` to the dependencies of your test:

```julia
julia> using Pkg; pkg"activate test; add TidyTest"
```

And then execute your tests:

```bash
$ julia --project -e "using Pkg; Pkg.test()"
```

For example:

![](sample/vhs/sample.gif)

The [`@run_tests`](#run_tests) macro automatically discovers all Julia source
files in the directory of `runtests.jl`, and includes all of them. The entire
block is wrapped in a single toplevel `@testset` using the custom test set type
[`SpinnerTestSet`](#spinnertestset). Test progress is reported using
[ProgressMeter.jl][], continuously updating the status as tests are completed.
If some tests fail (or throw an error), the issues are reported as they happen,
and a detailed test summary is printed upon completion, using the default test
reporting.

### Test filtering

The macro facilitates running tests selectively. Every command line argument is
used as a pattern, and only those tests are run which contain any of the
arguments as a substring. The search uses smart case matching: if any of the
patterns contains at least one capital letter, then matching is case-sensitive,
otherwise its case-insensitive. To pass command line arguments to `Pkg.test()`,
the `test_args` keyword argument must be used:

```bash
$ alias jlt='julia --project -e "using Pkg; Pkg.test(test_args=ARGS)"'
$ jlt some tests
# ...runs test files which have "some" or "test" occurring in their names
```

Alternatively, one can filter tests by passing a `filters` keyword argument to
the `@run_tests` macro, with a list of strings:

```julia
@run_tests filters=["some", "tests"]
```

## Example sessions

Here are some further examples, run in the [`sample`](sample) directory of this
repository.

When there are some tests that fail and/or throw an error, the issues are
reported immediately, the progress line is printed in red, and a detailed
summary is printed upon completion:

![](sample/vhs/full.gif)

When there are passing tests only, no details are shown. The color of the
progress line stays green:

![](sample/vhs/oo.gif)

Filtering is case-sensitive when the pattern contains uppercase characters.
Also, when there are broken tests, the color of the progress line turns yellow,
but still no details are printed:

![](sample/vhs/b.gif)

Detailed reporting can be forced with the `verbose=true` keyword argument even
for passing tests:

![](sample/vhs/oo-verbose.gif)

## Reference

### `@run_tests`

```julia
@run_tests [name] [dir="."] [filters=ARGS] [rest...]
```

Discover and include test (Julia) files from the directory of the caller, and
wrap them in a [`SpinnerTestSet`](#spinnertestset) for reporting. The name of
the testset is automatically derived from the package name, if the macro is
called from the `runtests.jl` file.

Optional arguments:

* `name`: explicitly name the testset;

* `dir="."`: discover tests in the provided directory (instead of the directory
  of the source file containing the macro call);

* `filters=[...]`: filter discovered source files - include only those which
  contain any of the filter strings as a substring;

* all other keyword arguments are passed directly to
  [`SpinnerTestSet`](#spinnertestset).

Filtering uses smart case matching: if any of the patterns contains at least one
capital letter, then matching is case-sensitive, otherwise its case-insensitive.


### `SpinnerTestSet`

```julia
SpinnerTestSet(desc::String; [width::Integer, verbose::Bool=false, rest...])
```

An implementation of the `AbstractTestSet` abstract class, that reports testing
progress using `ProgressMeter.ProgressUnknown`, continuously updating the status
as tests are completed.

Arguments:

* `desc`: the name of the testset;

* `width`: the display width of the progress line, defaults to the width of the
  terminal;

* `verbose=false`: whether to print a detailed summary even when none of the
  tests fail or throw an error;

* all other keyword arguments are passed directly to `Test.DefaultTestSet`.

## Similar packages

* [TestSetExcetions.jl][]

[ProgressMeter.jl]: https://github.com/timholy/ProgressMeter.jl
[TestSetExcetions.jl]: https://github.com/ssfrr/TestSetExtensions.jl
