#
# Combinators for setting output decorations.
#

immutable DecorateTool <: AbstractTool
    F::Tool
    decors::Decorations
end

DecorateTool(F::AbstractTool; decorations...) =
    DecorateTool(F, [Decoration(n, v) for (n, v) in sort(decorations)])

input(tool::DecorateTool) = input(tool.F)
output(tool::DecorateTool) =
    let otype = output(tool.F)
        for d in tool.decors
            otype = otype |> decorate(d)
        end
        otype
    end

run(tool::DecorateTool, iflow::InputFlow) =
    run(prim(tool), iflow)

prim(tool::DecorateTool) =
    let sig = output(tool)
        prim(tool.F) >> DecoratePrimTool(domain(sig))
    end

ThenDecorate(; decorations...) =
    Combinator(P -> DecorateTool(P; decorations...))

ThenTag(tag::Symbol) = ThenDecorate(tag=tag)

# Primitive decorator.

immutable DecoratePrimTool <: AbstractTool
    dom::Domain
end

input(tool::DecoratePrimTool) = Input(tool.dom)
output(tool::DecoratePrimTool) = Output(tool.dom)

run_prim(tool::DecoratePrimTool, vals::AbstractVector) =
    Column(OneTo(length(vals)+1), vals)

