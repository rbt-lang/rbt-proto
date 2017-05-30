#
# A vector of composite data stored in a column-oriented format.
#

abstract AbstractCompositeVector{R} <: AbstractVector{R}

@inline column(cv::AbstractCompositeVector, k::Int) =
    columns(cv)[k]

guesslength(cols::Columns) =
    !isempty(cols) ? length(cols[1]) : 0

guesstype(cols::Columns) =
    Tuple{map(datatype, cols)...}

guesstype(::Type{Any}, cols::Columns) =
    guesstype(cols)

guesstype{T}(::Type{T}, cols::Columns) = T

linearindexing{T<:AbstractCompositeVector}(::Type{T}) = Base.LinearFast()

Base.array_eltype_show_how(::AbstractCompositeVector) = (true, "")

Base.summary(cv::AbstractCompositeVector) =
    "$(length(cv))-element composite vector of $(typesummary(cv))"

function typesummary(cv::AbstractCompositeVector)
    names = fieldnames(eltype(cv))
    cols = columns(cv)
    fields =
        if eltype(names) == Symbol && length(names) == length(cols)
            map((n, c) -> "$n::$(typesummary(c))", names, cols)
        else
            map(typesummary, cols)
        end
    return string("{", join(fields, ", "), "}")
end

# Composite vector with an open signature.

immutable TupleVector{R,C<:ColumnTuple} <: AbstractCompositeVector{R}
    len::Int
    cols::C

    function TupleVector(len::Int, cols::C)
        @boundscheck for col in cols
            length(col) == len || error("unexpected column length")
        end
        new(len, cols)
    end
end

typealias RecordVector{R<:AbstractRecord} TupleVector{R}

TupleVector(len::Int, cols::ColumnTuple) =
    TupleVector{guesstype(cols),typeof(cols)}(len, cols)

TupleVector(len::Int, cols::Tuple{AbstractVector, Vararg{AbstractVector}}) =
    TupleVector(len, map(Column, cols))

TupleVector(cols::ColumnTuple) =
    TupleVector(guesslength(cols), cols)

TupleVector(cols::Tuple{AbstractVector, Vararg{AbstractVector}}) =
    TupleVector(map(Column, cols))

TupleVector(len::Int, cols::AbstractVector...) =
    TupleVector(len, map(Column, cols))

TupleVector(cols::AbstractVector...) =
    TupleVector(map(Column, cols))

function RecordVector(len::Int, fcols::Vector{Tuple{Symbol,Column}})
    nfields = length(fcols)
    fieldnames = Vector{Symbol}(nfields)
    fieldcols = Vector{Column}(nfields)
    fieldtypes = Vector{Type}(nfields)
    seen = Set{Symbol}()
    for (k, (field, col)) in enumerate(fcols)
        if field == Symbol("")
            field = Symbol("_", k)
        end
        if field in seen
            field = Symbol(field, "′")
        end
        fieldnames[k] = field
        fieldcols[k] = col
        fieldtypes[k] = datatype(col)
        push!(seen, field)
    end
    R = recordtype(fieldnames){fieldtypes...}
    cols = (fieldcols...)
    return TupleVector{R,typeof(cols)}(len, cols)
end

RecordVector(fcols::Vector{Tuple{Symbol,Column}}) =
    RecordVector(!isempty(fcols) ? length(fcols[1][2]) : 0, fcols)

RecordVector(len::Int; kwargs...) =
    RecordVector(len, collect(Tuple{Symbol,Column}, kwargs))

RecordVector(; kwargs...) =
    RecordVector(collect(Tuple{Symbol,Column}, kwargs))

@inline columns(tv::TupleVector) = tv.cols

@inline size(tv::TupleVector) = (tv.len,)

@inline length(tv::TupleVector) = tv.len

@inline getindex{R}(tv::TupleVector{R}, i::Int) =
    getdata(R, tv.cols, i)

@inline getindex{R,C}(tv::TupleVector{R,C}, idxs::AbstractVector{Int}) =
    TupleVector{R,C}(length(idxs), map(col -> col[idx], tv.cols))

# Composite vector with a hidden signature.

immutable DataVector <: AbstractCompositeVector{Any}
    meta::Any
    len::Int
    cols::ColumnVector

    function DataVector(meta, len::Int, cols::ColumnVector)
        @boundscheck for col in cols
            length(col) == len || error("unexpected column length")
        end
        new(meta, len, cols)
    end
end

DataVector(len::Int, cols::ColumnVector) =
    DataVector(Any, len, cols)

DataVector(cols::ColumnVector) =
    DataVector(Any, guesslength(cols), cols)

DataVector(len::Int, cols::AbstractVector...) =
    DataVector(len, collect(Column, cols))

DataVector(cols::AbstractVector...) =
    DataVector(collect(Column, cols))

convert(::Type{TupleVector}, dv::DataVector) =
    let cols = (dv.cols...), R = guesstype(dv.meta, dv.cols)
        TupleVector{R,typeof(cols)}(dv.len, cols)
    end

@inline columns(dv::DataVector) =
    dv.cols

@inline eltype(dv::DataVector) =
    guesstype(dv.meta, dv.cols)

@inline size(dv::DataVector) = (dv.len,)

@inline length(dv::DataVector) = dv.len

getindex(dv::DataVector, i::Int) =
    getdata(dv.meta, dv.cols, i)

getindex(dv::DataVector, idxs::AbstractVector{Int}) =
    DataVector(dv.meta, length(idxs), map(col -> col[idx], dv.cols))

Base.mapfoldl(f, op, v0, dv::DataVector) =
    mapfoldl(f, op, v0, convert(TupleVector, dv))

Base.mapfoldl(f, op, dv::DataVector) =
    mapfoldl(f, op, convert(TupleVector, dv))

Base.mapfoldr(f, op, v0, dv::DataVector) =
    mapfoldr(f, op, v0, convert(TupleVector, dv))

Base.mapfoldr(f, op, dv::DataVector) =
    mapfoldr(f, op, convert(TupleVector, dv))

Base.mapreduce(f, op, v0, dv::DataVector) =
    mapreduce(f, op, v0, convert(TupleVector, dv))

Base.mapreduce(f, op, dv::DataVector) =
    mapreduce(f, op, convert(TupleVector, dv))

Base.foreach(f, dv::DataVector) =
    foreach(f, convert(TupleVector, dv))

Base.map(f, dv::DataVector) =
    map(f, convert(TupleVector, dv))

