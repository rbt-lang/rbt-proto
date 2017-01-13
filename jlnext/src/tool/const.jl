#
# Constant primitive.
#

immutable ConstTool <: AbstractTool
    dom::Domain
    val
end

ConstTool(val) = ConstTool(typeof(val), val)

input(::ConstTool) = Input(Any)
output(tool::ConstTool) = Output(tool.dom)

run(tool::ConstTool, iflow::InputFlow) =
    OutputFlow(
        output(tool),
        run_const(length(iflow), tool.val))

run_const(len::Int, val) =
    Column(OneTo(len+1), fill(val, len))

Const(val) = Combinator(ConstTool(val))

Const(dom, val) = Combinator(ConstTool(dom, val))

