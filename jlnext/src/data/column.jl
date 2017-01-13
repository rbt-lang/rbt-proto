#
# A column of values with offsets.
#

# Summary of the column data.

type ColumnStat{T}
    count0::Nullable{Int}
    count1::Nullable{Int}
    min::Nullable{T}
    max::Nullable{T}

    ColumnStat() =
        new(Nullable{Int}(), Nullable{Int}(), Nullable{T}(), Nullable{T}())
end

# The column type.

immutable Column{T,O<:AbstractVector{Int},V<:AbstractVector} <:
        AbstractVector{SubArray{T,1,V,Tuple{UnitRange{Int}},true}}
    len::Int
    offs::O
    vals::V
    stat::ColumnStat{T}

    function Column(offs::O, vals::V)
        @assert length(offs) >= 1
        @assert offs[1] == 1
        @assert offs[end] == length(vals)+1

        return new(length(offs)-1, offs, vals, ColumnStat{T}())
    end
end

Column{T}(offs::AbstractVector{Int}, vals::AbstractVector{T}) =
    Column{T,typeof(offs),typeof(vals)}(offs, vals)

Column(data::AbstractVector) =
    Column(OneTo(length(data)+1), data)

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
    return Column(offs, vals)
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
    return Column(offs, vals)
end

Column(data::Column) = data

# Array interface.

size(col::Column) = (col.len,)

length(col::Column) = col.len

getindex(col::Column, i::Int) =
    let l = col.offs[i], r = col.offs[i+1]
        view(col.vals, l:r-1)
    end

function getindex{T,O,V}(col::Column{T,O,V}, idxs::AbstractVector{Int})
    offs = Vector{Int}(length(idxs)+1)
    offs[1] = 1
    i = 1
    for idx in idxs
        l = col.offs[idx]
        r = col.offs[idx+1]
        offs[i+1] = offs[i] + r - l
        i += 1
    end
    vlen = offs[end] - 1
    vidxs = Vector{Int}(vlen)
    i = 1
    for idx in idxs
        l = col.offs[idx]
        r = col.offs[idx+1]
        for j = l:r-1
            vidxs[i] = j
            i += 1
        end
    end
    return Column(offs, col.vals[vidxs])
end

function getindex{T,O<:OneTo,V}(col::Column{T,O,V}, idxs::AbstractVector{Int})
    offs = OneTo(length(idxs)+1)
    vals = col.vals[idxs]
    return Column(offs, vals)
end

function getindex{T,O,V}(col::Column{T,O,V}, idxs::OneTo)
    len = length(idxs)
    if len == col.len
        return col
    else
        return Column(
            col.offs[OneTo(len+1)],
            col.vals[OneTo(col.offs[len+1]-1)])
    end
end

function getindex{T,O<:OneTo,V}(col::Column{T,O,V}, idxs::OneTo)
    len = length(idxs)
    if len == col.len
        return col
    else
        return Column(col.offs[idxs], col.vals[idxs])
    end
end

Base.linearindexing{T,O,V}(::Type{Column{T,O,V}}) = Base.LinearFast()

Base.array_eltype_show_how(::Column) = (true, "")

# Attributes and properties.

offsets(col::Column) = col.offs
values(col::Column) = col.vals

