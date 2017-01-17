#
# Composition of queries.
#

immutable ComposeTool <: AbstractTool
    F::Tool
    G::Tool

    function ComposeTool(F::Tool, G::Tool)
        @assert fits(output(F), input(G)) "($F) >> ($G)"
        return new(F, G)
    end

    ComposeTool(F, G) = ComposeTool(convert(Tool, F), convert(Tool, G))
end

>>(F::AbstractTool, G::AbstractTool) =
    isa(F, HereTool) && domain(input(F)) == domain(input(G)) ?
        G : ComposeTool(F, G)

input(tool::ComposeTool) =
    let Fsig = input(tool.F), Gsig = input(tool.G)
        Input(
            domain(Fsig),
            ibound(mode(Fsig), mode(Gsig)))
    end

output(tool::ComposeTool) =
    let Fsig = output(tool.F), Gsig = output(tool.G)
        Output(
            domain(Gsig),
            obound(mode(Fsig), mode(Gsig)),
            decorations(Gsig))
    end

function run(tool::ComposeTool, iflow::InputFlow)
    iflow1 = narrow(iflow, input(tool.F))
    oflow1 = run(tool.F, iflow1)
    iflow2 = distribute(narrow(iflow, input(tool.G)), oflow1)
    oflow2 = run(tool.G, iflow2)
    return OutputFlow(
        output(tool),
        Column(
            run_compose(offsets(oflow1), offsets(oflow2)),
            values(oflow2)))
end

run_compose(offs1::AbstractVector{Int}, offs2::AbstractVector{Int}) =
    Int[offs2[offs1[i]] for i in eachindex(offs1)]

run_compose(offs1::OneTo, offs2::OneTo) = offs1

run_compose(offs1::OneTo, offs2::AbstractVector{Int}) = offs2

run_compose(offs1::AbstractVector{Int}, offs2::OneTo) = offs1

