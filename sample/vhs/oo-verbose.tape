Output vhs/oo-verbose.gif

Require julia

Set Shell "bash"
Set FontSize 18
Set Width 1200
Set Height 320
Set Padding 15
Set Theme "Builtin Tango Dark"

Type "bat --plain runtests.jl" Sleep 500ms Enter
Sleep 2s
Type "julia --project runtests.jl oo" Sleep 500ms Enter
Sleep 25s
