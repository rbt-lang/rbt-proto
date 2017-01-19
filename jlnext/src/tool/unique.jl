#
# The unique combinator.
#

immutable UniqueTool <: AbstractTool
    F::Tool
end

input(tool::UniqueTool) = input(tool.F)
output(tool::UniqueTool) = output(tool.F)

run(tool::UniqueTool, iflow::InputFlow) =
    run(prim(tool), iflow)

prim(tool::UniqueTool) =
    RecordTool(prim(tool.F)) >> UniquePrimTool(output(tool.F))

Unique(F::Combinator) =
    Combinator(
        P ->
            let Q = Start(P)
                P >> UniqueTool(F(Q))
            end)

ThenUnique() =
    Combinator(P -> UniqueTool(P))

# The unique primitive.

immutable UniquePrimTool <: AbstractTool
    sig::Output
end

input(tool::UniquePrimTool) = Input((tool.sig,))
output(tool::UniquePrimTool) = tool.sig

run_prim(tool::UniquePrimTool, ds::DataSet) =
    run_unique(length(ds), offsets(ds, 1), values(ds, 1))

function run_unique{T}(len::Int, offs::AbstractVector{Int}, vals::AbstractVector{T})
    dict = Dict{T,Int}()
    offs′ = Vector{Int}(len+1)
    offs′[1] = 1
    idxs = Vector{Int}(length(vals))
    seen = fill(0, length(vals))
    n = 1
    for k in 1:len
        l = offs[k]
        r = offs[k+1]
        for i = l:r-1
            idx = get!(dict, vals[i], i)
            last = seen[idx]
            if last < l
                seen[idx] = i
                idxs[n] = idx
                n += 1
            end
        end
        offs′[k+1] = n
    end
    resize!(idxs, n-1)
    return Column(offs′, vals[idxs])
end

