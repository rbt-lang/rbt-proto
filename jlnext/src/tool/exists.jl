#
# The exists combinator.
#

immutable ExistsTool <: AbstractTool
    F::Tool
end

input(tool::ExistsTool) = input(tool.F)
output(::ExistsTool) = Output(Bool)

run(tool::ExistsTool, iflow::InputFlow) =
    run(prim(tool), iflow)

prim(tool::ExistsTool) =
    RecordTool(prim(tool.F)) >> ExistsPrimTool()

Exists(F) =
    Combinator(
        P ->
            let Q = Start(P)
                P >> ExistsTool(F(Q))
            end)

ThenExists() =
    Combinator(P -> ExistsTool(P))

# The exists primitive.

immutable ExistsPrimTool <: AbstractTool
end

input(::ExistsPrimTool) = Input((Output(Any, optional=true, plural=true),))

output(::ExistsPrimTool) = Output(Bool)

run_prim(tool::ExistsPrimTool, ds::DataSet) =
    run_exists(length(ds), offsets(ds, 1))

function run_exists(len::Int, ioffs::AbstractVector{Int})
    vals = Vector{Bool}(len)
    for i = 1:len
        vals[i] = ioffs[i+1] > ioffs[i]
    end
    return Column(OneTo(len+1), vals)
end

