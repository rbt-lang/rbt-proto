#
# Record vector that hides its signature.
#

immutable DataVector <: AbstractVector{Tuple}
    len::Int
    cols::Vector{Column}

    function DataVector(len::Int, cols::Vector{Column})
        for col in cols
            length(col) == len || error("unexpected column length")
        end
        new(len, cols)
    end
end

DataVector(len::Int, cols::AbstractVector...) =
    DataVector(len, collect(Column, cols))

DataVector(cols::AbstractVector...) =
    DataVector(!isempty(cols) ? length(cols[1]) : 0, collect(Column, cols))

datatype(dv::DataVector) =
    Tuple{map(datatype, dv.cols)...}

getdata(dv::DataVector) =
    TupleVector(dv.len, dv.cols...)

getdata(R::Type, dv::DataVector) =
    TupleVector(R, dv.len, dv.cols...)

# Vector interface.

size(dv::DataVector) = (dv.len,)

length(dv::DataVector) = dv.len

getindex(dv::DataVector, i::Int) =
    getdata((dv.cols...), i)

getindex(dv::DataVector, idxs::AbstractVector{Int}) =
    DataVector(length(idxs), Column[col[idxs] for col in dv.cols])

Base.linearindexing(::Type{DataVector}) = Base.LinearFast()

Base.array_eltype_show_how(::DataVector) = (true, "")

Base.summary(dv::DataVector) =
    "$(dv.len)-element vector of $(datatype(dv))"

Base.mapfoldl(f, op, v0, dv::DataVector) =
    mapfoldl(f, op, v0, getdata(dv))

Base.mapfoldl(f, op, dv::DataVector) =
    mapfoldl(f, op, getdata(dv))

Base.mapfoldr(f, op, v0, dv::DataVector) =
    mapfoldr(f, op, v0, getdata(dv))

Base.mapfoldr(f, op, dv::DataVector) =
    mapfoldr(f, op, getdata(dv))

Base.mapreduce(f, op, v0, dv::DataVector) =
    mapreduce(f, op, v0, getdata(dv))

Base.mapreduce(f, op, dv::DataVector) =
    mapreduce(f, op, getdata(dv))

Base.foreach(f, dv::DataVector) =
    foreach(f, getdata(dv))

Base.map(f, dv::DataVector) =
    map(f, getdata(dv))

