#
# A mapping with integer keys.
#

immutable MappingTool <: AbstractTool
    dom::Domain
    flow::OutputFlow
end

MappingTool(dom, sig, col) = MappingTool(dom, OutputFlow(sig, Column(col)))
MappingTool(dom, sig, offs, vals) = MappingTool(dom, OutputFlow(sig, Column(offs, vals)))

input(tool::MappingTool) = Input(tool.dom)

output(tool::MappingTool) = output(tool.flow)

run_prim(tool::MappingTool, ivals::AbstractVector{Int}) =
    let col = column(tool.flow)
        col[ivals]
    end

Mapping(flow) = Combinator(MappingTool(flow))

Mapping(sig, col) = Combinator(MappingTool(sig, col))

Mapping(sig, offs, vals) = Combinator(MappingTool(sig, offs, vals))

