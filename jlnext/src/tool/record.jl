#
# Record constructor.
#

immutable RecordTool <: AbstractTool
    Fs::Vector{Tool}
end

RecordTool(Fs::AbstractTool...) = RecordTool(collect(Tool, Fs))

input(tool::RecordTool) = ibound(Input, (input(F) for F in tool.Fs)...)

output(tool::RecordTool) =
    Output(((output(F) for F in tool.Fs)...))

run(tool::RecordTool, iflow::InputFlow) =
    let len = length(iflow)
        OutputFlow(
            output(tool),
            Column(
                OneTo(len+1),
                DataSet(
                    len,
                    OutputFlow[run(F, narrow(iflow, input(F))) for F in tool.Fs])))
    end

Record(Fs...) =
    Combinator(
        P ->
            let Q = HereTool(domain(output(P)))
                P >> RecordTool((F(Q) for F in Fs)...)
            end)

