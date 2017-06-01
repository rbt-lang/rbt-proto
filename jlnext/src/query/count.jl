#
# Count combinator.
#

CountQuery(q::Query) =
    RecordQuery(q) >> Query(CountSig(), Input([Output(Any) |> setoptional() |> setplural()]), Output(Int))

immutable CountSig <: AbstractPrimitive
end

ev(::CountSig, dv::DataVector) =
    count_impl(length(dv), offsets(dv, 1))

function count_impl(len::Int, ioffs::AbstractVector{Int})
    @boundscheck checkbounds(ioffs, len+1)
    vals = Vector{Int}(len)
    @inbounds l = ioffs[1]
    for i = 1:len
        @inbounds r = ioffs[i+1]
        @inbounds vals[i] = r - l
        l = r
    end
    return PlainColumn(vals)
end

