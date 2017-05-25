#
# A vector of tuples stored in a column-oriented format.
#

immutable TupleVector{R,C<:Tuple{Vararg{Column}}} <: AbstractVector{R}
    len::Int
    cols::C

    function TupleVector(len::Int, cols::C)
        for col in cols
            length(col) == len || error("unexpected column length")
        end
        new(len, cols)
    end
end

TupleVector(R::Type, len::Int, cols::Column...) =
    TupleVector{R, typeof(cols)}(len, cols)

TupleVector(len::Int, cols::Column...) =
    TupleVector{Tuple{map(datatype, cols)...},typeof(cols)}(len, cols)

TupleVector(len::Int, cols::AbstractVector...) =
    TupleVector(len, map(Column, cols)...)

TupleVector(cols::Column...) =
    TupleVector(!isempty(cols) ? length(cols[1]) : 0, cols...)

TupleVector(cols::AbstractVector...) =
    TupleVector(map(Column, cols)...)

typealias RecordVector TupleVector{AbstractRecord}

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
    Recordvector(len, collect(Tuple{Symbol,Column}, kwargs))

RecordVector(; kwargs...) =
    RecordVector(collect(Tuple{Symbol,Column}, kwargs))

# Vector interface.

size(tv::TupleVector) = (tv.len,)

length(tv::TupleVector) = tv.len

getindex{R}(tv::TupleVector{R}, i::Int) =
    getdata(R, tv.cols, i)

getindex{R}(tv::TupleVector{R}, idxs::AbstractVector{Int}) =
    TupleVector(R, length(idxs), map(col -> col[idxs], tv.cols)...)

Base.linearindexing{R<:TupleVector}(::Type{R}) = Base.LinearFast()

Base.array_eltype_show_how(::TupleVector) = (true, "")

Base.summary{R,C}(tv::TupleVector{R,C}) =
    "$(tv.len)-element vector of $R"

