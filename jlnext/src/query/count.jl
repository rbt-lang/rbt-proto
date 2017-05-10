#
# Count combinator.
#

CountQuery(q::Query) =
    RecordQuery(q) >> Query(CountSig(), Input([Output(Any) |> setoptional() |> setplural()]), Output(Int))

immutable CountSig <: AbstractPrimitive
end

ev(::CountSig, ds::DataSet) =
    ev_count(length(ds), offsets(ds, 1))

function ev_count(len::Int, ioffs::AbstractVector{Int})
    vals = Vector{Int}(len)
    for i = 1:len
        vals[i] = ioffs[i+1] - ioffs[i]
    end
    return Column(OneTo(len+1), vals)
end

