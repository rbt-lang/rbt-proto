#
# Identity primitive.
#

immutable HereTool <: AbstractTool
    dom::Domain
end

input(tool::HereTool) = Input(tool.dom)
output(tool::HereTool) = Output(tool.dom)

run_prim(tool::HereTool, vals::AbstractVector) =
    Column(OneTo(length(vals)+1), vals)

Here() = Combinator(P -> P)

Start() = HereTool(Unit)
Start(dom) = HereTool(dom)
Start(tool::AbstractTool) = Start(domain(output(tool)))
