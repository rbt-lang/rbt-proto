#
# Rabbit, a combinator-based query language.
#

__precompile__()

module RBT

include("export.jl")
include("importbase.jl")
include("syntax.jl")
include("immdict.jl")
include("type.jl")
include("data.jl")
include("tool.jl")
include("query.jl")
include("bind.jl")

end

