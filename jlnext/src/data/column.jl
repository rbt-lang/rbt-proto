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

# Array interface.

size(col::Column) = (col.len,)
length(col::Column) = col.len
getindex(col::Column, i::Int) =
    let l = col.offs[i], r = col.offs[i+1]
        view(col.vals, l:r-1)
    end
Base.array_eltype_show_how(::Column) = (true, "")

# Attributes and properties.

offsets(col::Column) = col.offs
values(col::Column) = col.vals

