#
# Identity primitive.
#

immutable HereTool <: AbstractTool
    dom::Domain
    decors::OutputDecorations
end

HereTool(dom) = HereTool(dom, ())

input(tool::HereTool) = Input(tool.dom)
output(tool::HereTool) = Output(tool.dom, OutputMode(), tool.decors)

run_prim(tool::HereTool, vals::AbstractVector) =
    Column(OneTo(length(vals)+1), vals)

Here() = Combinator(P -> P)

Start() = HereTool(Unit)
Start(dom) = HereTool(dom)
Start(tool::AbstractTool) =
    HereTool(domain(output(tool)), decorations(output(tool)))

