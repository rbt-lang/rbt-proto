#
# A value vector indexed by a vector of offsets.
#

# Mutable view over column slices.

type ColumnCursor{T,V<:AbstractVector} <: AbstractVector{T}
    pos::Int
    l::Int
    r::Int
    vals::V

    @inline ColumnCursor(vals) =
        new(0, 1, 1, vals)

    @inline function ColumnCursor(pos, l, r, vals)
        @boundscheck checkbounds(vals, l:r-1)
        new(pos, l, r, vals)
    end
end

ColumnCursor(vals::AbstractVector) =
    ColumnCursor{eltype(vals),typeof(vals)}(vals)

ColumnCursor(pos, l, r, vals::AbstractVector) =
    ColumnCursor{eltype(vals),typeof(vals)}(pos, l, r, vals)

@inline size(cr::ColumnCursor) = (cr.r - cr.l,)

@inline length(cr::ColumnCursor) = cr.r - cr.l

@inline function getindex(cr::ColumnCursor, i::Int)
    @boundscheck checkbounds(cr, i)
    @inbounds val = cr.vals[cr.l + i - 1]
    val
end

linearindexing{CR<:ColumnCursor}(::Type{CR}) = Base.LinearFast()

Base.array_eltype_show_how(::ColumnCursor) = (true, "")

# The column type.

immutable Column{OPT,PLU,O<:AbstractVector{Int},V<:AbstractVector} <: AbstractVector{ColumnCursor}
    len::Int
    offs::O
    vals::V

    function Column(offs::O, vals::V)
        len = length(offs)-1
        return new(len, offs, vals)
    end
end

typealias PlainColumn Column{false,false}
typealias OptionalColumn Column{true,false}
typealias PluralColumn Column{true,true}
typealias NonEmptyPluralColumn Column{false,true}

@inline function Column(offs::OneTo, vals::AbstractVector)
    @boundscheck length(offs) == length(vals) + 1 || error("ill-formed offset vector")
    Column{false,false,typeof(offs),typeof(vals)}(offs, vals)
end

function Column(offs::AbstractVector{Int}, vals::AbstractVector)
    optional = false
    plural = false
    @boundscheck !isempty(offs) && offs[1] == 1 && offs[end] == length(vals)+1 || error("ill-formed offset vector")
    l = 1
    for k = 2:endof(offs)
        @inbounds r = offs[k]
        @boundscheck l <= r || error("ill-formed offset vector")
        optional |= l == r
        plural |= l+1 < r
    end
    Column{optional,plural}(offs, vals)
end

@inline PlainColumn(vals::AbstractVector) =
    let offs = OneTo(length(vals)+1)
        PlainColumn(offs, vals)
    end

@inline PlainColumn(offs::OneTo, vals::AbstractVector) =
    Column{false,false,typeof(offs),typeof(vals)}(offs, vals)

@inline PlainColumn(::AbstractVector{Int}, vals::AbstractVector) =
    PlainColumn(vals)

@inline OptionalColumn(offs::AbstractVector{Int}, vals::AbstractVector) =
    Column{true,false,typeof(offs),typeof(vals)}(offs, vals)

@inline PluralColumn(offs::AbstractVector{Int}, vals::AbstractVector) =
    Column{true,true,typeof(offs),typeof(vals)}(offs, vals)

@inline NonEmptyPluralColumn(offs::AbstractVector{Int}, vals::AbstractVector) =
    Column{false,true,typeof(offs),typeof(vals)}(offs, vals)

convert(::Type{Column}, col::Column) = col

convert(::Type{Column}, data::AbstractVector) =
    let offs = OneTo(length(data)+1)
        Column{false,false}(offs, data)
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
    @inbounds for (i, item) in enumerate(data)
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
    @inbounds for (i, items) in enumerate(data)
        copy!(vals, k, items)
        k += length(items)
        offs[i+1] = k
    end
    Column{true,true}(offs, vals)
end

# Cursor interface.

@inline cursor(col::Column) =
    ColumnCursor(col.vals)

@inline function cursor(col::Column, pos::Int)
    @boundscheck checkbounds(col.offs, pos:pos+1)
    ColumnCursor(pos, col.offs[pos], col.offs[pos+1], col.vals)
end

@inline done(col::Column, cr::ColumnCursor) = cr.pos >= col.len

@inline function next!(col::Column, cr::ColumnCursor)
    @boundscheck checkbounds(col.offs, cr.pos+1)
    cr.pos += 1
    cr.l = cr.r
    @inbounds cr.r = col.offs[cr.pos+1]
    cr
end

# Array interface.

eltype{OPT,PLU,O,V}(::Type{Column{OPT,PLU,O,V}}) = ColumnCursor{eltype(V),V}

@inline size(col::Column) = (col.len,)

@inline length(col::Column) = col.len

@inline getindex(col::Column, i::Int) =
    cursor(col, i)

function getindex{OPT,PLU,O,V}(col::Column{OPT,PLU,O,V}, idxs::AbstractVector{Int})
    @boundscheck checkbounds(col, idxs)
    offs = Vector{Int}(length(idxs)+1)
    @inbounds offs[1] = top = 1
    i = 1
    @inbounds for idx in idxs
        l = col.offs[idx]
        r = col.offs[idx+1]
        offs[i+1] = top = top + r - l
        i += 1
    end
    perm = Vector{Int}(offs[end]-1)
    i = 1
    @inbounds for idx in idxs
        l = col.offs[idx]
        r = col.offs[idx+1]
        copy!(perm, i, l:r-1)
        i += r - l
    end
    @inbounds vals = col.vals[perm]
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

linearindexing{C<:Column}(::Type{C}) = Base.LinearFast()

Base.array_eltype_show_how(::Column) = (true, "")

Base.summary(col::Column) =
"$(col.len)-element column of $(typesummary(col))"

typesummary(col::Column) =
    "$(typesummary(col.vals))$(valsigil(col))"

typesummary(vals::AbstractVector) =
    "$(eltype(vals))"

summary{OPT,PLU,O,V}(col::Column{OPT,PLU,O,V}) =
    "$(shapesummary(valtype(col)))$(valsigil(col))"

# Attributes and properties.

valsigil{C<:Column{false,false}}(::Type{C}) = ""
valsigil{C<:Column{true,false}}(::Type{C}) = "?"
valsigil{C<:Column{false,true}}(::Type{C}) = "+"
valsigil{C<:Column{true,true}}(::Type{C}) = "*"
valsigil(col::Column) = valsigil(typeof(col))

Base.keytype{OPT,PLU,O,V}(::Type{Column{OPT,PLU,O,V}}) = eltype(O)
Base.valtype{OPT,PLU,O,V}(::Type{Column{OPT,PLU,O,V}}) = eltype(V)
Base.keytype(col::Column) = keytype(typeof(col))
Base.valtype(col::Column) = valtype(typeof(col))

isoptional{C<:Union{Column{false,false},Column{false,true}}}(::Type{C}) = false
isoptional{C<:Union{Column{true,false},Column{true,true}}}(::Type{C}) = true
isplural{C<:Union{Column{false,false},Column{true,false}}}(::Type{C}) = false
isplural{C<:Union{Column{false,true},Column{true,true}}}(::Type{C}) = true
isoptional(col::Column) = isoptional(typeof(col))
isplural(col::Column) = isplural(typeof(col))

offsets(col::Column) = col.offs
values(col::Column) = col.vals

# Data view.

typealias ColumnTuple Tuple{Vararg{Column}}
typealias ColumnVector AbstractVector{Column}
typealias Columns Union{ColumnTuple,ColumnVector}

datatype(col::Column{false,false}) =
    eltype(col.vals)

datatype(col::Column{true,false}) =
    Nullable{eltype(col.vals)}

datatype{OPT}(col::Column{OPT,true}) =
    SubArray{eltype(col.vals),1,typeof(col.vals),Tuple{UnitRange{Int}},true}

datatype(cols::Columns) =
    Tuple{map(datatype, cols)...}

@inline function getdata(::Type{Any}, col::Column{false,false}, i::Int)
    col.vals[i]
end

@inline function getdata(::Type{Any}, col::Column{true,false}, i::Int)
    l = col.offs[i]
    r = col.offs[i+1]
    T = Nullable{eltype(col.vals)}
    l < r ? convert(T, col.vals[l]) : convert(T, nothing)
end

@inline function getdata{OPT}(::Type{Any}, col::Column{OPT,true}, i::Int)
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

@inline getdata(::Type{Any}, ::Tuple{}, i) = ()

@inline getdata(::Type{Any}, cols::Tuple{Column, Vararg{Any}}, i::Int) =
    (getdata(Any, cols[1], i), getdata(Any, Base.tail(cols), i)...)

@inline getdata(::Type{Tuple{}}, ::Tuple{}, i) = ()

@inline getdata{T<:Tuple{Any,Vararg{Any}}}(::Type{T}, cols::Tuple{Column, Vararg{Any}}, i::Int) =
    (getdata(Base.tuple_type_head(T), cols[1], i), getdata(Base.tuple_type_tail(T), Base.tail(cols), i)...)

@inline getdata{T<:AbstractRecord}(::Type{T}, cols::Tuple{Vararg{Column}}, i::Int) =
    T(getdata(fieldtypes(T), cols, i)...)

@inline getdata{T}(::Type{T}, cols::ColumnVector, i::Int) =
    getdata(T, (cols...), i)

