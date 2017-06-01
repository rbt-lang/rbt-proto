#
# Plural constants.
#

CollectionQuery(idom, odom, set::AbstractVector) =
    Query(
        CollectionSig(set),
        Input(convert(Domain, idom)),
        Output(convert(Domain, odom)) |> setoptional() |> setplural())

CollectionQuery(odom, set::AbstractVector) =
    CollectionQuery(Void, odom, set)

CollectionQuery{T}(set::AbstractVector{T}) =
    CollectionQuery(Void, T, set)

immutable CollectionSig <: AbstractPrimitive
    set::AbstractVector
end

ev(sig::CollectionSig, ::Input, oty::Output, iflow::InputFlow) =
    OutputFlow(oty, collection_impl(sig.set, length(iflow)))

function collection_impl(set::AbstractVector, len::Int)
    card = length(set)
    if len == 1
        return Column(Int[1, card+1], set)
    end
    offs = Int[1 + i*card for i = 0:len]
    idxs = len > 0 ? Int[j for i = 1:len for j = 1:card] : Int[]
    vals = set[idxs]
    return Column(offs, vals)
end

