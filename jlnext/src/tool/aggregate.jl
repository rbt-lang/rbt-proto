#
# Aggregate combinators.
#

immutable AggregateTool <: AbstractTool
    op::Function
    itype::Type
    otype::Type
    haszero::Bool
    F::Tool

    function AggregateTool(op::Function, itype::Type, otype::Type, haszero::Bool, F::Tool)
        @assert method_exists(op, (AbstractVector{itype},))
        @assert fits(domain(output(F)), Domain(itype))

        return new(op, itype, otype, haszero, F)
    end
end

AggregateTool(op::Function, itype::Type, otype::Type, haszero::Bool, F) =
    AggregateTool(op, itype, otype, haszero::Bool, convert(Tool, F))

AggregateTool(op::Function, otype::Type, haszero::Bool, F::AbstractTool) =
    AggregateTool(op, datatype(domain(output(F))), otype, haszero, F)

AggregateTool(op::Function, haszero::Bool, F::AbstractTool) =
    let T = datatype(domain(output(F)))
        AggregateTool(op, T, T, haszero, F)
    end

input(tool::AggregateTool) = input(tool.F)

output(tool::AggregateTool) =
    Output(tool.otype) |> setoptional((!tool.haszero && isoptional(output((tool.F)))))

run(tool::AggregateTool, iflow::InputFlow) =
    run(prim(tool), iflow)

prim(tool::AggregateTool) =
    let optional = isoptional(output(tool.F))
        RecordTool(prim(tool.F)) >>
        AggregatePrimTool(tool.op, tool.itype, tool.otype, tool.haszero, optional)
    end

Aggregate(op::Function, itype::Type, otype::Type, haszero::Bool, F::Combinator) =
    Combinator(
        P ->
            let Q = Start(P)
                P >> AggregateTool(op, itype, otype, haszero, F(Q))
            end)

Aggregate(op::Function, otype::Type, haszero::Bool, F::Combinator) =
    Combinator(
        P ->
            let Q = Start(P)
                P >> AggregateTool(op, otype, haszero, F(Q))
            end)

Aggregate(op::Function, haszero::Bool, F::Combinator) =
    Combinator(
        P ->
            let Q = Start(P)
                P >> AggregateTool(op, haszero, F(Q))
            end)

ThenAggregate(op::Function, itype::Type, otype::Type, haszero::Bool, F::Combinator=Here()) =
    Combinator(P -> AggregateTool(op, itype, otype, haszero, F(P)))

ThenAggregate(op::Function, otype::Type, haszero::Bool, F::Combinator=Here()) =
    Combinator(P -> AggregateTool(op, otype, haszero, F(P)))

ThenAggregate(op::Function, haszero::Bool, F::Combinator=Here()) =
    Combinator(P -> AggregateTool(op, haszero, F(P)))

AnyOf(F::Combinator) = Aggregate(any, Bool, Bool, true, F)
AllOf(F::Combinator) = Aggregate(all, Bool, Bool, true, F)
MaxOf(F::Combinator) = Aggregate(maximum, false, F)
MinOf(F::Combinator) = Aggregate(minimum, false, F)
SumOf(F::Combinator) = Aggregate(sum, true, F)
MeanOf(F::Combinator) = Aggregate(mean, Float64, false, F)

ThenAny(F::Combinator=Here()) = ThenAggregate(any, Bool, Bool, true, F)
ThenAll(F::Combinator=Here()) = ThenAggregate(all, Bool, Bool, true, F)
ThenMax(F::Combinator=Here()) = ThenAggregate(maximum, false, F)
ThenMin(F::Combinator=Here()) = ThenAggregate(minimum, false, F)
ThenSum(F::Combinator=Here()) = ThenAggregate(sum, true, F)
ThenMean(F::Combinator=Here()) = ThenAggregate(mean, Float64, false, F)

# Aggregate primitive.

immutable AggregatePrimTool <: AbstractTool
    op::Function
    itype::Type
    otype::Type
    haszero::Bool
    optional::Bool
end

input(tool::AggregatePrimTool) =
    Input((Output(tool.itype) |> setoptional(tool.optional) |> setplural(),))

output(tool::AggregatePrimTool) =
    Output(tool.otype) |> setoptional(!tool.haszero && tool.optional)

run_prim(tool::AggregatePrimTool, ds::DataSet) =
    tool.haszero || !tool.optional ?
        run_plain_aggregate(tool.op, tool.otype, length(ds), column(ds, 1)) :
        run_aggregate(tool.op, tool.otype, length(ds), column(ds, 1))

function run_plain_aggregate{T}(op::Function, otype::Type{T}, len::Int, arg::Column)
    argoffs = offsets(arg)
    argvals = values(arg)
    offs = OneTo(len+1)
    vals = Vector{T}(len)
    for k = 1:len
        l = argoffs[k]
        r = argoffs[k+1]
        vals[k] = op(view(argvals, l:r-1))
    end
    return Column(offs, vals)
end

function run_aggregate{T}(op::Function, otype::Type{T}, len::Int, arg::Column)
    argoffs = offsets(arg)
    size = 0
    for k = 1:len
        if argoffs[k] < argoffs[k+1]
            size += 1
        end
    end
    if size == len
        return run_plain_aggregate(op, otype, len, arg)
    end
    argvals = values(arg)
    offs = Vector{Int}(len+1)
    offs[1] = 1
    vals = Vector{T}(size)
    n = 1
    for k = 1:len
        l = argoffs[k]
        r = argoffs[k+1]
        if l < r
            vals[n] = op(view(argvals, l:r-1))
            n += 1
        end
        offs[k+1] = n
    end
    return Column(offs, vals)
end

