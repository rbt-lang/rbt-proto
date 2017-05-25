#
# A value vector indexed by a vector of offsets.
#

# A slice of a column between two offsets.

immutable ColumnSlice{OPT,PLU,V<:AbstractVector}
    vals::V
    l::Int
    r::Int
end

show(io::IO, cs::ColumnSlice) = show(io, getdata(cs))

@inline getdata(cs::ColumnSlice{false,false}) =
    cs.vals[cs.l]

@inline getdata(cs::ColumnSlice{true,false}) =
    let T = Nullable{eltype(cs.vals)}
        cs.l < cs.r ? convert(T, cs.vals[cs.l]) : convert(T, nothing)
    end

@inline getdata{OPT}(cs::ColumnSlice{OPT,true}) =
    view(cs.vals, cs.l:cs.r-1)

@inline getdata{T}(::Type{T}, cs::ColumnSlice{false,false}) =
    convert(T, cs.vals[cs.l])

@inline getdata{T}(::Type{T}, cs::ColumnSlice{true,false}) =
    cs.l < cs.r ? convert(T, cs.vals[cs.l]) : convert(T, nothing)

@inline getdata{T,OPT}(::Type{T}, cs::ColumnSlice{OPT,true}) =
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

convert(::Type{Column}, col::Column) = col

convert(::Type{Column}, data::AbstractVector) =
    let offs = OneTo(length(data)+1), vals = data
        Column{false,false}(offs, vals)
    end

function convert{T<:Nullable}(::Type{Column}, data::Vector{T})
    len = 0
    for item in data
        if !isnull(item)
            len += 1
        end
    end
    offs = Vector{Int}(length(data)+1)
    vals = Vector{eltype(T)}(len)
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

function convert{T<:Vector}(::Type{Column}, data::Vector{T})
    len = 0
    for items in data
        len += length(items)
    end
    offs = Vector{Int}(length(data)+1)
    vals = Vector{eltype(T)}(len)
    offs[1] = k = 1
    for (i, items) in enumerate(data)
        copy!(vals, k, items)
        k += length(items)
        offs[i+1] = k
    end
    Column{true,true}(offs, vals)
end

datatype(col::Column{false,false}) =
    eltype(col.vals)

datatype(col::Column{true,false}) =
    Nullable{eltype(col.vals)}

datatype{OPT}(col::Column{OPT,true}) =
    SubArray{eltype(col.vals),1,typeof(col.vals),Tuple{UnitRange{Int}},true}

@inline function getdata(col::Column{false,false}, i::Int)
    col.vals[i]
end

@inline function getdata(col::Column{true,false}, i::Int)
    l = col.offs[i]
    r = col.offs[i+1]
    T = Nullable{eltype(col.vals)}
    l < r ? convert(T, col.vals[l]) : convert(T, nothing)
end

@inline function getdata{OPT}(col::Column{OPT,true}, i::Int)
    l = col.offs[i]
    r = col.offs[i+1]
    view(col.vals, l:r-1)
end

@inline function getdata{T}(::Type{T}, col::Column{false,false}, i::Int)
    convert(T, col.vals[i])
end

@inline function getdata{T}(::Type{T}, col::Column{true,false}, i::Int)
    l = col.offs[i]
    r = col.offs[i+1]
    l < r ? convert(T, col.vals[l]) : convert(T, nothing)
end

@inline function getdata{T,OPT}(::Type{T}, col::Column{OPT,true}, i::Int)
    l = col.offs[i]
    r = col.offs[i+1]
    convert(T, view(col.vals, l:r-1))
end

@inline getdata(::Tuple{}, i) = ()

@inline getdata(css::Tuple{Column, Vararg{Any}}, i::Int) =
    (getdata(css[1], i), getdata(Base.tail(css), i)...)

@inline getdata(::Type{Tuple{}}, ::Tuple{}, i) = ()

@inline getdata{T<:Tuple{Any,Vararg{Any}}}(::Type{T}, css::Tuple{Column, Vararg{Any}}, i::Int) =
    (getdata(Base.tuple_type_head(T), css[1], i), getdata(Base.tuple_type_tail(T), Base.tail(css), i)...)

@inline getdata{T<:AbstractRecord}(::Type{T}, css::Tuple{Vararg{Column}}, i::Int) =
    T(getdata(fieldtypes(T), css, i)...)

# Array interface.

size(col::Column) = (col.len,)

length(col::Column) = col.len

@inline getindex{OPT,PLU,O,V}(col::Column{OPT,PLU,O,V}, i::Int) =
    let l = col.offs[i], r = col.offs[i+1]
        ColumnSlice{OPT,PLU,V}(col.vals, l, r)
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

Base.summary(col::Column) =
    "$(col.len)-element column of $(valuetype(col))$(valuesigil(col))"

# Attributes and properties.

valuesigil{C<:Column{false,false}}(::Type{C}) = ""
valuesigil{C<:Column{true,false}}(::Type{C}) = "?"
valuesigil{C<:Column{false,true}}(::Type{C}) = "+"
valuesigil{C<:Column{true,true}}(::Type{C}) = "*"
valuesigil(col::Column) = valuesigil(typeof(col))

valuetype{OPT,PLU,O,V}(::Type{Column{OPT,PLU,O,V}}) = eltype(V)
valuetype(col::Column) = valuetype(typeof(col))

isoptional{C<:Union{Column{false,false},Column{false,true}}}(::Type{C}) = false
isoptional{C<:Union{Column{true,false},Column{true,true}}}(::Type{C}) = true
isplural{C<:Union{Column{false,false},Column{true,false}}}(::Type{C}) = false
isplural{C<:Union{Column{false,true},Column{true,true}}}(::Type{C}) = true
isoptional(col::Column) = isoptional(typeof(col))
isplural(col::Column) = isplural(typeof(col))

offsets(col::Column) = col.offs
values(col::Column) = col.vals

