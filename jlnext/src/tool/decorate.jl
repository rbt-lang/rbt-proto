#
# Combinators for setting output decorations.
#

immutable DecorateTool <: AbstractTool
    F::Tool
    decors::OutputDecorations
end

DecorateTool(F::AbstractTool; decorations...) =
    DecorateTool(F, ((OutputDecoration(n, v) for (n, v) in sort(decorations))...))

input(tool::DecorateTool) = input(tool.F)
output(tool::DecorateTool) = Output(output(tool.F); tool.decors...)

run(tool::DecorateTool, iflow::InputFlow) =
    run(prim(tool), iflow)

prim(tool::DecorateTool) =
    let sig = output(tool)
        prim(tool.F) >> DecoratePrimTool(domain(sig), decorations(sig))
    end

ThenDecorate(; decorations...) =
    Combinator(P -> DecorateTool(P; decorations...))

ThenTag(tag::Symbol) = ThenDecorate(tag=tag)

# Primitive decorator.

immutable DecoratePrimTool <: AbstractTool
    dom::Domain
    decors::OutputDecorations
end

input(tool::DecoratePrimTool) = Input(tool.dom)
output(tool::DecoratePrimTool) = Output(tool.dom, OutputMode(), tool.decors)

run_prim(tool::DecoratePrimTool, vals::AbstractVector) =
    Column(OneTo(length(vals)+1), vals)

