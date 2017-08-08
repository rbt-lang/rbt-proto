#
# Concatenation.
#

function MergeQuery(qs::Vector{Query})
    dom = obound(Domain[domain(output(q)) for q in qs])
    optional = all(isoptional(q) for q in qs)
    q = RecordQuery(qs)
    return q >> Query(MergeSig(), Input(domain(output(q))), Output(dom) |> setoptional(optional) |> setplural())
end

MergeQuery(q1::Query, qrest...) =
    MergeQuery([q1], qrest...)

MergeQuery(qs1::Vector{Query}, q2::Query, qrest...) =
    MergeQuery([qs1..., q2], qrest...)

MergeQuery(qs1::Vector{Query}, qs2::Vector{Query}, qrest...) =
    MergeQuery([qs1..., qs2...], qrest...)

immutable MergeSig <: AbstractPrimitive
end

ev(::MergeSig, ::Vector{Query}, ::Input, oty::Output, iflow::InputFlow) =
    OutputFlow(oty, merge_impl(datatype(domain(oty)), length(iflow), columns(values(iflow))))

function merge_impl(T::DataType, len::Int, cols::Vector{Column})
    optional = true
    size = 0
    for col in cols
        size += length(col.vals)
        if !isoptional(col)
            optional = false
        end
    end
    offs = Vector{Int}(len+1)
    offs[1] = 1
    vals = Vector{T}(size)
    n = 1
    for k = 1:len
        for col in cols
            cr = cursor(col, k)
            copy!(vals, n, cr)
            n += length(cr)
        end
        offs[k+1] = n
    end
    return Column{optional,true}(offs, vals)
end

