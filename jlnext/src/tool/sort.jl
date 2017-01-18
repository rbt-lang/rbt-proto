#
# Sorting.
#

immutable SortTool <: AbstractTool
    F::Tool
end

input(tool::SortTool) = input(tool.F)
output(tool::SortTool) = output(tool.F)

run(tool::SortTool, iflow::InputFlow) =
    run(prim(tool), iflow)

prim(tool::SortTool) =
    RecordTool(prim(tool.F)) >> SortPrimTool(output(tool.F))

Sort(F::Combinator) =
    Combinator(
        P ->
            let Q = Start(P)
                P >> SortTool(F(Q))
            end)

ThenSort() = Combinator(P -> SortTool(P))

ThenAsc() = ThenDecorate(rev=false)
ThenDesc() = ThenDecorate(rev=true)

# The sorting primitive.

immutable SortPrimTool <: AbstractTool
    sig::Output
end

input(tool::SortPrimTool) = Input((tool.sig,))
output(tool::SortPrimTool) = tool.sig

run_prim(tool::SortPrimTool, ds::DataSet) =
    let rev = decoration(tool.sig, :rev, false)
        run_sort(column(ds, 1), rev)
    end

function run_sort(col::Column, rev::Bool)
    len = length(col)
    offs = offsets(col)
    vals = copy(values(col))
    for k = 1:len
        l = offs[k]
        r = offs[k+1]
        sort!(view(vals, l:r-1), rev=rev)
    end
    return Column(offs, vals)
end

