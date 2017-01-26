#
# Framing the input context.
#

immutable FrameTool <: AbstractTool
    F::Tool
end

input(tool::FrameTool) = Input(input(tool.F), relative=false)
output(tool::FrameTool) = output(tool.F)

prim(tool::FrameTool) =
    FrameTool(prim(tool.F))

run(tool::FrameTool, iflow::InputFlow) =
    let iflow =
        InputFlow(
            iflow.ctx,
            domain(iflow),
            iflow.vals,
            InputFrame(OneTo(iflow.len+1)),
            iflow.paramflows)
        run(tool.F, iflow)
    end

ThenFrame() = Combinator(P -> FrameTool(P))

