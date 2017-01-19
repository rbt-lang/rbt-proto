#
# Vector with values stored in a sorted dictionary.
#

immutable DictVector{T} <: AbstractVector{T}
    ptr::Vector{Int}
    dict::Vector{T}
end

function DictVector{T}(vals::AbstractVector{T})
    len = length(vals)
    v2i = Dict{T,Int}()
    ptr = Vector{Int}(len)
    for k = 1:len
        ptr[k] = get!(v2i, vals[k], k)
    end
    ulen = length(v2i)
    vs = collect(keys(v2i))
    is = collect(values(v2i))
    perm = sortperm(vs)
    recode = Vector{Int}(ulen)
    for k = 1:ulen
        recode[is[k]] = perm[k]
    end
    for k = 1:len
        ptr[k] = recode[ptr[k]]
    end
    dict = vs[perm]
    return DictVector{T}(ptr, dict)
end

keys(dv::DictVector) = dv.ptr
values(dv::DictVector) = dv.dict

size(dv::DictVector) = (length(dv.ptr),)
length(dv::DictVector) = length(dv.ptr)

getindex(dv::DictVector, i::Int) = dv.dict[dv.ptr[i]]

getindex(dv::DictVector, idxs::AbstractVector{Int}) =
    DictVector(dv.ptr[idxs], dv.dict)

