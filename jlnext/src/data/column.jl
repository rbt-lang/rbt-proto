#
# A value vector indexed by a vector of offsets.
#

# A slice of a column between two offsets.

immutable ColumnSlice{OPT,PLU,V<:AbstractVector}
    vals::V
    l::Int
    r::Int
end

show(io::IO, cs::ColumnSlice) = show(io, dataview(cs))

dataview(cs::ColumnSlice{false,false}) =
    cs.vals[cs.l]

dataview(cs::ColumnSlice{true,false}) =
    let T = Nullable{eltype(cs.vals)}
        cs.l < cs.r ? T(cs.vals[cs.l]) : T()
    end

dataview{OPT}(cs::ColumnSlice{OPT,true}) =
    view(cs.vals, cs.l:cs.r-1)

dataview{T}(::Type{T}, cs::ColumnSlice{false,false}) =
    convert(T, cs.vals[cs.l])

dataview{T}(::Type{T}, cs::ColumnSlice{true,false}) =
    cs.l < cs.r ? convert(T, cs.vals[cs.l]) : convert(T, nothing)

dataview{T,OPT}(::Type{T}, cs::ColumnSlice{OPT,true}) =
    convert(T, view(cs.vals, cs.l:cs.r-1))


# The column type.

immutable Column{OPT,PLU,O<:AbstractVector{Int},V<:AbstractVector} <:
        AbstractVector{ColumnSlice{OPT,PLU,V}}
    len::Int
    offs::O
    vals::V

    function Column(offs::O, vals::V)
        len = length(offs)-1
        @assert len > 0 && offs[1] == 1 && offs[end] == length(vals)+1
        return new(len, offs, vals)
    end
end

typealias PlainColumn Column{false,false}
typealias OptionalColumn Column{true,false}
typealias PluralColumn Column{true,true}
typealias NonEmptyPluralColumn Column{false,true}

Column(offs::AbstractVector{Int}, vals::AbstractVector) =
    Column{true,true,typeof(offs),typeof(vals)}(offs, vals)

PlainColumn(offs::AbstractVector{Int}, vals::AbstractVector) =
    Column{false,false,typeof(offs),typeof(vals)}(offs, vals)

OptionalColumn(offs::AbstractVector{Int}, vals::AbstractVector) =
    Column{true,false,typeof(offs),typeof(vals)}(offs, vals)

PluralColumn(offs::AbstractVector{Int}, vals::AbstractVector) =
    Column{true,true,typeof(offs),typeof(vals)}(offs, vals)

NonEmptyPluralColumn(offs::AbstractVector{Int}, vals::AbstractVector) =
    Column{false,true,typeof(offs),typeof(vals)}(offs, vals)

Column(data::AbstractVector) =
    let offs = OneTo(length(data)+1), vals = data
        Column{false,false}(offs, vals)
    end

function Column{T}(data::AbstractVector{Nullable{T}})
    len = 0
    for item in data
        if !isnull(item)
            len += 1
        end
    end
    offs = Vector{Int}(length(data)+1)
    vals = Vector{T}(len)
    offs[1] = k = 1
    for (i, item) in enumerate(data)
        if !isnull(item)
            vals[k] = get(item)
            k += 1
        end
        offs[i+1] = k
    end
    Column{true,false}(offs, vals)
end

function Column{T}(data::AbstractVector{Vector{T}})
    len = 0
    for items in data
        len += length(items)
    end
    offs = Vector{Int}(length(data)+1)
    vals = Vector{T}(len)
    offs[1] = k = 1
    for (i, items) in enumerate(data)
        for item in items
            vals[k] = item
            k += 1
        end
        offs[i+1] = k
    end
    Column{true,true}(offs, vals)
end

Column(col::Column) = col

function dataview(col::Column{false,false})
    @boundscheck col.len == 1 && length(col.vals) == 1 || throw(BoundsError())
    col.vals[1]
end

function dataview(col::Column{true,false})
    @boundscheck col.len == 1 && 0 <= length(col.vals) <= 1 || throw(BoundsError())
    T = Nullable{eltype(col.vals)}
    !isempty(col.vals) ? T(col.vals[1]) : T()
end

function dataview(col::Column{false,true})
    @boundscheck col.len == 1 && 1 <= length(col.vals) || throw(BoundsError())
    col.vals
end

function dataview(col::Column{true,true})
    @boundscheck col.len == 1 || throw(BoundsError())
    col.vals
end

function dataview{T}(::Type{T}, col::Column{false,false})
    @boundscheck col.len == 1 && length(col.vals) == 1 || throw(BoundsError())
    convert(T, col.vals[1])
end

function dataview{T}(::Type{T}, col::Column{true,false})
    @boundscheck col.len == 1 && 0 <= length(col.vals) <= 1 || throw(BoundsError())
    !isempty(col.vals) ? convert(T, col.vals[1]) : convert(T, nothing)
end

function dataview{T}(::Type{T}, col::Column{false,true})
    @boundscheck col.len == 1 && 1 <= length(col.vals) || throw(BoundsError())
    convert(T, col.vals)
end

function dataview{T}(::Type{T}, col::Column{true,true})
    @boundscheck col.len == 1 || throw(BoundsError())
    convert(T, col.vals)
end

# Array interface.

size(col::Column) = (col.len,)

length(col::Column) = col.len

getindex{O,V}(col::Column{false,false,O,V}, i::Int) =
    let l = col.offs[i], r = col.offs[i+1]
        @boundscheck 1 <= r == l+1 <= length(col.vals)+1 || throw(BoundsError())
        ColumnSlice{false,false,V}(col.vals, l, r)
    end

getindex{O,V}(col::Column{true,false,O,V}, i::Int) =
    let l = col.offs[i], r = col.offs[i+1]
        @boundscheck 1 <= l <= r <= l+1 && r <= length(col.vals)+1 || throw(BoundsError())
        ColumnSlice{true,false,V}(col.vals, l, r)
    end

getindex{O,V}(col::Column{false,true,O,V}, i::Int) =
    let l = col.offs[i], r = col.offs[i+1]
        @boundscheck 1 <= l < r <= length(col.vals)+1 || throw(BoundsError())
        ColumnSlice{false,true,V}(col.vals, l, r)
    end

getindex{O,V}(col::Column{true,true,O,V}, i::Int) =
    let l = col.offs[i], r = col.offs[i+1]
        @boundscheck 1 <= l <= r <= length(col.vals)+1 || throw(BoundsError())
        ColumnSlice{true,true,V}(col.vals, l, r)
    end

function getindex{OPT,PLU,O,V}(col::Column{OPT,PLU,O,V}, idxs::AbstractVector{Int})
    offs = Vector{Int}(length(idxs)+1)
    offs[1] = 1
    i = 1
    for idx in idxs
        l = col.offs[idx]
        r = col.offs[idx+1]
        offs[i+1] = offs[i] + r - l
        i += 1
    end
    perm = Vector{Int}(offs[end]-1)
    i = 1
    for idx in idxs
        l = col.offs[idx]
        r = col.offs[idx+1]
        for j = l:r-1
            perm[i] = j
            i += 1
        end
    end
    vals = col.vals[perm]
    return Column{OPT,PLU}(offs, vals)
end

function getindex{OPT,PLU,O<:OneTo,V}(col::Column{OPT,PLU,O,V}, idxs::AbstractVector{Int})
    offs = OneTo(length(idxs)+1)
    vals = col.vals[idxs]
    return Column{OPT,PLU}(offs, vals)
end

function getindex{OPT,PLU,O,V}(col::Column{OPT,PLU,O,V}, idxs::OneTo)
    len = length(idxs)
    if len == col.len
        return col
    else
        return typeof(col)(
            col.offs[OneTo(len+1)],
            col.vals[OneTo(col.offs[len+1]-1)])
    end
end

function getindex{OPT,PLU,O<:OneTo,V}(col::Column{OPT,PLU,O,V}, idxs::OneTo)
    len = length(idxs)
    if len == col.len
        return col
    else
        return typeof(col)(col.offs[idxs], col.vals[idxs])
    end
end

function vcat{OPT1,OPT2,PLU1,PLU2}(col1::Column{OPT1,PLU1}, col2::Column{OPT2,PLU2})
    offs = Vector{Int}(col1.len+col2.len+1)
    for k = 1:col1.len
        offs[k] = col1.offs[k]
    end
    L = col1.offs[col1.len+1]
    for k = 1:col2.len+1
        offs[col1.len+k] = col2.offs[k] + L
    end
    vals = vcat(col1.vals, col2.vals)
    return Column{OPT1||OPT2,PLU1||PLU2}(offs, vals)
end

vcat{OPT1,OPT2,PLU1,PLU2}(col1::Column{OPT1,PLU1,OneTo{Int}}, col2::Column{OPT2,PLU2,OneTo{Int}}) =
    let offs = OneTo(col1.len+col2.len+1), vals = vcat(col1.vals, col2.vals)
        Column{OPT1||OPT2,PLU1||PLU2}(offs, vals)
    end

Base.linearindexing{C<:Column}(::Type{C}) = Base.LinearFast()

Base.array_eltype_show_how(::Column) = (true, "")

# Attributes and properties.

offsets(col::Column) = col.offs
values(col::Column) = col.vals
isoptional{OPT,PLU}(col::Column{OPT,PLU}) = OPT
isplural{OPT,PLU}(col::Column{OPT,PLU}) = PLU

