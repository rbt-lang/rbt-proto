#
# Mapping with integer indexes.
#

MappingQuery(idom, oty, col::Column) =
    Query(
        MappingSig(col),
        Input(convert(Domain, idom)),
        convert(Output, oty))

MappingQuery(idom, oty, offs::AbstractVector{Int}, vals::AbstractVector) =
    MappingQuery(idom, oty, Column(offs, vals))

MappingQuery{T}(idom, oty, data::AbstractVector{Vector{T}}) =
    MappingQuery(idom, convert(Output, oty) |> setoptional() |> setplural(), Column(data))

MappingQuery{T}(idom, oty, data::AbstractVector{Nullable{T}}) =
    MappingQuery(idom, convert(Output, oty) |> setoptional, Column(data))

MappingQuery(idom, oty, data::AbstractVector) =
    MappingQuery(idom, oty, Column(data))

MappingQuery{T}(idom, data::AbstractVector{Vector{T}}) =
    MappingQuery(idom, T, data)

MappingQuery{T}(idom, data::AbstractVector{Nullable{T}}) =
    MappingQuery(idom, T, data)

MappingQuery{T}(idom, data::AbstractVector{T}) =
    MappingQuery(idom, T, data)

MappingQuery(data::AbstractVector) =
    MappingQuery(Int, data)

immutable MappingSig <: AbstractPrimitive
    col::Column
end

ev(sig::MappingSig, idxs::AbstractVector) =
    sig.col[idxs]

