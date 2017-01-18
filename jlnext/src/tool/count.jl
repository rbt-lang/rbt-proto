#
# The count combinator.
#

immutable CountTool <: AbstractTool
    F::Tool
end

input(tool::CountTool) = input(tool.F)
output(::CountTool) = Output(Int)

run(tool::CountTool, iflow::InputFlow) =
    run(prim(tool), iflow)

prim(tool::CountTool) =
    RecordTool(prim(tool.F)) >> CountPrimTool()

Count(F) =
    Combinator(
        P ->
            let Q = Start(P)
                P >> CountTool(F(Q))
            end)

ThenCount() =
    Combinator(P -> CountTool(P))

# The count primitive.

immutable CountPrimTool <: AbstractTool
end

input(::CountPrimTool) = Input((Output(Any, optional=true, plural=true),))

output(::CountPrimTool) = Output(Int)

run_prim(tool::CountPrimTool, ds::DataSet) =
    run_count(length(ds), offsets(ds, 1))

function run_count(len::Int, ioffs::AbstractVector{Int})
    vals = Vector{Int}(len)
    for i = 1:len
        vals[i] = ioffs[i+1] - ioffs[i]
    end
    return Column(OneTo(len+1), vals)
end

