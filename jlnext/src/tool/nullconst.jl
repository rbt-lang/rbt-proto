#
# Null constant.
#

immutable NullConstTool <: AbstractTool
end

input(::NullConstTool) = Input(Any)
output(::NullConstTool) = Output(Zero, optional=true)

run(tool::NullConstTool, iflow::InputFlow) =
    OutputFlow(
        output(tool),
        Column(fill(1, length(iflow)+1), Zero[]))

NullConst() = Combinator(NullConstTool())

