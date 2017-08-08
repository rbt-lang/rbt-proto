#
# Multiplexer.
#

function IfThenElseQuery(qcond::Query, qthen::Query, qelse::Query)
    dom = ibound(domain(input(qthen)), domain(input(qelse)))
    q = RecordQuery(ItQuery(dom), LiftQuery(c -> c ? 1 : 2, qcond))
    q >>
    Query(
        SwitchSig(),
        [qthen, qelse],
        Input(domain(output(q))),
        Output(
            obound(domain(output(qthen)), domain(output(qelse))),
            obound(mode(output(qcond)), mode(output(qthen)), mode(output(qelse)))))
end

immutable SwitchSig <: AbstractSignature
end

function ev(::SwitchSig, args::Vector{Query}, ity::Input, oty::Output, iflow::InputFlow)
    ivals = values(column(values(iflow), 1))
    imux = column(values(iflow), 2)
    ocols = Vector{Column}(length(args))
    coloty = Output(domain(fields(domain(ity))[1]), OutputMode(true, isplural(imux)))
    for k = 1:length(args)
        arg = args[k]
        ocol = switch_split_impl(ivals, imux, k)
        colflow = OutputFlow(coloty, ocol)
        icolflow = distribute(narrow(iflow, input(arg)), colflow)
        ocols[k] = column(ev(arg, icolflow))
    end
    col = switch_merge_impl(datatype(domain(oty)), imux, ocols)
    return OutputFlow(oty, col)
end

function switch_split_impl(ivals::AbstractVector, mux::Column, k::Int)
    size = 0
    for m in values(mux)
        if m == k
            size += 1
        end
    end
    offs = Vector{Int}(length(mux)+1)
    offs[1] = 1
    idxs = Vector{Int}(size)
    cr = cursor(mux)
    n = 1
    while !done(mux, cr)
        next!(mux, cr)
        for m in cr
            if m == k
                idxs[n] = cr.pos
                n += 1
            end
        end
        offs[cr.pos+1] = n
    end
    vals = ivals[idxs]
    return Column{true,isplural(mux)}(offs, vals)
end

function switch_merge_impl(T::DataType, mux::Column, cols::Vector{Column})
    optional = isoptional(mux)
    plural = isplural(mux)
    size = 0
    for col in cols
        optional |= isoptional(col)
        plural |= isplural(col)
        size += length(values(col))
    end
    offs = Vector{Int}(length(mux)+1)
    offs[1] = 1
    vals = Vector{T}(size)
    n = 1
    crs = ColumnCursor[]
    for col in cols
        push!(crs, cursor(col))
    end
    muxcr = cursor(mux)
    while !done(mux, muxcr)
        next!(mux, muxcr)
        for m in muxcr
            col = cols[m]
            cr = crs[m]
            next!(col, cr)
            copy!(vals, n, cr)
            n += length(cr)
        end
        offs[muxcr.pos+1] = n
    end
    return Column{optional,plural}(offs, vals)
end

