#
# Query primitives and combinators.
#

# A query interface.

abstract AbstractTool

show(io::IO, tool::AbstractTool) =
    print(io, "$(input(tool)) -> $(output(tool))")

input(tool::AbstractTool) = error("not implemented")

output(tool::AbstractTool) = error("not implemented")

run(tool::AbstractTool, iflow::InputFlow) = error("not implemented")

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

# Unary combinator interface.

immutable Combinator
    combinator::Function
end

Combinator(tool::AbstractTool) =
    Combinator(P -> P >> tool)

(c::Combinator)(tool::AbstractTool)::AbstractTool =
    c.combinator(tool)

include("tool/here.jl")
include("tool/const.jl")
include("tool/nullconst.jl")
include("tool/collection.jl")
include("tool/mapping.jl")
include("tool/compose.jl")

