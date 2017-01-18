#
# Query primitives and combinators.
#

# A query interface.

abstract AbstractTool

show(io::IO, tool::AbstractTool) =
    print(io, "$(input(tool)) -> $(output(tool))")

input(tool::AbstractTool) = error("not implemented")

output(tool::AbstractTool) = error("not implemented")

run(tool::AbstractTool, iflow::InputFlow) =
    OutputFlow(output(tool), run_prim(tool, values(iflow)))

run_prim(tool::AbstractTool, ivals::AbstractVector) = error("not implemented")

run(tool::AbstractTool, ctx::InputContext=InputContext(), dom=Domain(Unit), vals::AbstractVector=[nothing]) =
    run(tool, InputFlow(ctx, dom, vals))

run(tool::AbstractTool, dom, vals::AbstractVector) =
    run(tool, InputFlow(InputContext(), dom, vals))

run{T}(tool::AbstractTool, vals::AbstractVector{T}) =
    run(tool, InputFlow(InputContext(), T, vals))

function execute{T}(tool::AbstractTool, val::T=nothing)
    osig = output(tool)
    iflow = InputFlow(InputContext(), T, T[val])
    oflow = run(tool, iflow)
    return oflow[1]
end

prim(tool::AbstractTool) = tool

# Query wrapper.

immutable Tool <: AbstractTool
    tool::AbstractTool
    isig::Input
    osig::Output

    Tool(tool::AbstractTool) =
        new(tool, input(tool), output(tool))
end

convert(::Type{Tool}, tool::Tool) = tool
convert(::Type{Tool}, tool::AbstractTool) = Tool(tool)

input(tool::Tool) = tool.isig
output(tool::Tool) = tool.osig

run(tool::Tool, iflow::InputFlow)::OutputFlow = run(tool.tool, iflow)

prim(tool::Tool) = Tool(prim(tool.tool))

# Unary combinator interface.

immutable Combinator
    combinator::Function
end

Combinator(tool::AbstractTool) =
    Combinator(P -> P >> tool)

(c::Combinator)(tool::AbstractTool)::AbstractTool =
    c.combinator(tool)

(c::Combinator)(d::Combinator)::Combinator =
    Combinator(P -> c(d(P)))

include("tool/here.jl")
include("tool/decorate.jl")
include("tool/const.jl")
include("tool/nullconst.jl")
include("tool/collection.jl")
include("tool/mapping.jl")
include("tool/compose.jl")
include("tool/record.jl")
include("tool/field.jl")
include("tool/count.jl")
include("tool/exists.jl")
include("tool/op.jl")
include("tool/aggregate.jl")
include("tool/sieve.jl")
include("tool/sort.jl")
include("tool/take.jl")
include("tool/connect.jl")

