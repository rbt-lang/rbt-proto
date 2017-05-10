#
# Exists combinator.
#

ExistsQuery(q::Query) =
    RecordQuery(q) >> Query(ExistsSig(), Input([Output(Any) |> setoptional() |> setplural()]), Output(Bool))

immutable ExistsSig <: AbstractPrimitive
end

ev(::ExistsSig, ds::DataSet) =
    ev_exists(length(ds), offsets(ds, 1))

function ev_exists(len::Int, ioffs::AbstractVector{Int})
    vals = Vector{Bool}(len)
    for i = 1:len
        vals[i] = ioffs[i+1] > ioffs[i]
    end
    return Column(OneTo(len+1), vals)
end

