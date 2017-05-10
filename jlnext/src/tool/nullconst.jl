#
# Null constant.
#

immutable NullConstTool <: AbstractTool
end

input(::NullConstTool) = Input(Any)
output(::NullConstTool) = Output(None) |> setoptional()

run(tool::NullConstTool, iflow::InputFlow) =
    OutputFlow(
        output(tool),
        Column(fill(1, length(iflow)+1), None[]))

NullConst() = Combinator(NullConstTool())

