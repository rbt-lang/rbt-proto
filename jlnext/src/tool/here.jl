#
# Identity primitive.
#

immutable HereTool <: AbstractTool
    dom::Domain
end

input(tool::HereTool) = Input(tool.dom)
output(tool::HereTool) = Output(tool.dom)

run(tool::HereTool, iflow::InputFlow) =
    OutputFlow(
        output(tool),
        Column(
            OneTo(length(iflow)+1),
            values(iflow)))

Here() = Combinator(P -> P)

Start() = HereTool(Unit)

