#
# The filter combinator.
#

immutable SieveTool <: AbstractTool
    F::Tool

    function SieveTool(F::Tool)
        @assert !isplural(output(F))
        @assert fits(domain(output(F)), Bool)
        return new(F)
    end
end

SieveTool(F) = SieveTool(convert(Tool, F))

input(tool::SieveTool) = input(tool.F)
output(tool::SieveTool) =
    let dom = domain(input(tool.F))
        Output(dom) |> setoptional()
    end

run(tool::SieveTool, iflow::InputFlow) =
    run(prim(tool), iflow)

prim(tool::SieveTool) =
    let dom = domain(input(tool.F))
        RecordTool(HereTool(dom), prim(tool.F)) >> SievePrimTool(dom)
    end

ThenFilter(F::Combinator) =
    Combinator(
        P ->
            let Q = Start(P)
                P >> SieveTool(F(Q)) >> HereTool(domain(output(Q)))
            end)

# The sieve primitive.

immutable SievePrimTool <: AbstractTool
    dom::Domain
end

input(tool::SievePrimTool) =
    Input((Output(tool.dom), Output(Bool) |> setoptional()))

output(tool::SievePrimTool) =
    Output(tool.dom) |> setoptional()

run_prim(tool::SievePrimTool, ds::DataSet) =
    isplain(output(flow(ds, 2))) ?
        run_plain_sieve(values(ds, 1), values(ds, 2)) :
        run_sieve(values(ds, 1), offsets(ds, 2), values(ds, 2))

function run_plain_sieve(vals::AbstractVector, predvals::AbstractVector{Bool})
    len = length(vals)
    size = 0
    for pred in predvals
        if pred
            size += 1
        end
    end
    if size == len
        return Column(OneTo(len+1), vals)
    end
    offs = Vector{Int}(len+1)
    offs[1] = 1
    idxs = Vector{Int}(size)
    n = 1
    for k in eachindex(predvals)
        if predvals[k]
            idxs[n] = k
            n += 1
        end
        offs[k+1] = n
    end
    return Column(offs, vals[idxs])
end

function run_sieve(vals::AbstractVector, predoffs::AbstractVector{Int}, predvals::AbstractVector{Bool})
    len = length(vals)
    size = 0
    for pred in predvals
        if pred
            size += 1
        end
    end
    if size == len
        return Column(OneTo(len+1), vals)
    end
    offs = Vector{Int}(len+1)
    offs[1] = 1
    idxs = Vector{Int}(size)
    n = 1
    for k in 1:len
        l = predoffs[k]
        r = predoffs[k+1]
        if l < r && predvals[l]
            idxs[n] = k
            n += 1
        end
        offs[k+1] = n
    end
    return Column(offs, vals[idxs])
end

