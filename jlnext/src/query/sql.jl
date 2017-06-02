#
# Querying data using SQL.
#

type SQLTable
    sname::String
    name::String
    nattrs::Int
    attrnames::Vector{String}
    attrtypes::Vector{Type}
    attrisnulls::Vector{Bool}
    attruniques::Vector{Bool}
    sortattrs::Vector{Int}
end

SQLCollectionQuery(uri::String, tab::SQLTable, decors::Decorations=NO_DECORATIONS) =
    let dom = Domain(Symbol(uri, "#", tab.sname, "#", tab.name)) |> setdecorations(decors)
        Query(
            SQLEntitySig(uri, tab),
            Input(Void),
            Output(dom) |> setoptional() |> setplural())
    end

SQLFieldQuery(uri::String, tab::SQLTable, attr::Int, decors::Decorations=NO_DECORATIONS) =
    let idom = Domain(Symbol(uri, "#", tab.sname, "#", tab.name)),
        odom = Domain(tab.attrtypes[attr]) |> setdecorations(decors),
        optional = tab.attrisnulls[attr]
        Query(
            SQLFieldSig(uri, tab, attr),
            Input(idom),
            Output(odom) |> setoptional(optional))
    end

SQLLinkQuery(uri::String, itab::SQLTable, iattr::Int, otab::SQLTable, oattr::Int, decors::Decorations=NO_DECORATIONS) =
    let idom = Domain(Symbol(uri, "#", itab.sname, "#", itab.name)),
        odom = Domain(Symbol(uri, "#", otab.sname, "#", otab.name)) |> setdecorations(decors),
        optional = itab.attrisnulls[iattr],
        plural = !otab.attruniques[oattr]
        Query(
            SQLLinkSig(uri, itab, iattr, otab, oattr),
            Input(idom),
            Output(odom) |> setoptional(optional) |> setplural(plural))
    end

immutable SQLEntitySig <: AbstractPrimitive
    uri::String
    tab::SQLTable
end

immutable SQLFieldSig <: AbstractPrimitive
    uri::String
    tab::SQLTable
    attr::Int
end

immutable SQLLinkSig <: AbstractPrimitive
    uri::String
    itab::SQLTable
    iattr::Int
    otab::SQLTable
    oattr::Int
end

function ev(sig::SQLEntitySig, ::Input, oty::Output, iflow::InputFlow)
    dv = sqltable(iflow.ctx, sig.uri, sig.tab)
    col = collection_impl(OneTo(length(dv)), length(iflow))
    return OutputFlow(oty, col)
end

function ev(sig::SQLFieldSig, ::Input, oty::Output, iflow::InputFlow)
    dv = sqltable(iflow.ctx, sig.uri, sig.tab)
    col = dv.cols[sig.attr]
    idxs = values(iflow)
    return OutputFlow(oty, col[idxs])
end

function ev(sig::SQLLinkSig, ::Input, oty::Output, iflow::InputFlow)
    idv = sqltable(iflow.ctx, sig.uri, sig.itab)
    odv = sqltable(iflow.ctx, sig.uri, sig.otab)
    icol = idv.cols[sig.iattr][values(iflow)]
    ocol = odv.cols[sig.oattr]
    unique = sig.otab.attruniques[sig.oattr]
    col =
        if unique
            plain_join_impl(icol, ocol)
        else
            join_impl(icol, ocol)
        end
    return OutputFlow(oty, col)
end

function plain_join_impl(icol::Column{false,false}, ocol::Column{false,false})
    ovals = values(ocol)
    perm = sortperm(ovals)
    kptrs = (1:length(ovals))[perm]
    kvals = ovals[perm]
    vals = Vector{Int}(length(icol))
    cr = cursor(icol)
    while !done(icol, cr)
        next!(icol, cr)
        ptr = searchsortedfirst(kvals, cr[1])
        val = kptrs[ptr]
        vals[cr.pos] = val
    end
    return PlainColumn(vals)
end

function plain_join_impl{IOPT,OOPT}(icol::Column{IOPT,false}, ocol::Column{OOPT,false})
    ovals = values(ocol)
    optrs = Vector{Int}(length(ovals))
    ocr = cursor(ocol)
    while !done(ocol, ocr)
        next!(ocol, ocr)
        if !isempty(ocr)
            optrs[ocr.l] = ocr.pos
        end
    end
    perm = sortperm(ovals)
    kptrs = optrs[perm]
    kvals = ovals[perm]
    vals = Vector{Int}(length(icol.vals))
    cr = cursor(icol)
    while !done(icol, cr)
        next!(icol, cr)
        if !isempty(cr)
            ptr = searchsortedfirst(kvals, cr[1])
            val = kptrs[ptr]
            vals[cr.l] = val
        end
    end
    return Column{IOPT,false}(offsets(icol), vals)
end

function join_impl{IOPT,OOPT}(icol::Column{IOPT,false}, ocol::Column{OOPT,false})
    ovals = values(ocol)
    optrs = Vector{Int}(length(ovals))
    ocr = cursor(ocol)
    while !done(ocol, ocr)
        next!(ocol, ocr)
        if !isempty(ocr)
            optrs[ocr.l] = ocr.pos
        end
    end
    perm = sortperm(ovals)
    kptrs = optrs[perm]
    kvals = ovals[perm]
    size = 0
    cr = cursor(icol)
    while !done(icol, cr)
        next!(icol, cr)
        if !isempty(cr)
            ptr = searchsorted(kvals, cr[1])
            size += length(ptr)
        end
    end
    offs = Vector{Int}(length(icol)+1)
    vals = Vector{Int}(size)
    cr = cursor(icol)
    offs[1] = 1
    n = 1
    while !done(icol, cr)
        next!(icol, cr)
        if !isempty(cr)
            ptr = searchsorted(kvals, cr[1])
            copy!(vals, n, kptrs, ptr.start, length(ptr))
            n += length(ptr)
        end
        offs[cr.pos+1] = n
    end
    return Column{IOPT,true}(offs, vals)
end

function sqltable(ctx::Dict{Symbol,Any}, uri::String, tab::SQLTable)
    if !(:sql in keys(ctx))
        ctx[:sql] = Dict{Any,Any}()
    end
    sqlctx = ctx[:sql]
    if !((uri, :conn) in keys(sqlctx))
        sqlctx[(uri, :conn)] = connect(uri)
    end
    conn = sqlctx[(uri, :conn)]
    if !((uri, :tab, tab.sname, tab.name) in keys(sqlctx))
        sqlbuf = IOBuffer()
        print(sqlbuf, "SELECT ")
        comma = false
        for attrname in tab.attrnames
            if comma
                print(sqlbuf, ", ")
            end
            comma = true
            print(sqlbuf, '"', attrname, '"')
        end
        print(sqlbuf, " FROM ", '"', tab.sname, '"', ".", '"', tab.name, '"')
        if !isempty(tab.sortattrs)
            print(sqlbuf, " ORDER BY ")
            comma = false
            for sortattr in tab.sortattrs
                if comma
                    print(sqlbuf, ", ")
                end
                comma = true
                print(sqlbuf, sortattr)
            end
        end
        sql = String(sqlbuf)
        dv = execute(conn, sql)
        cols = Column[]
        for (k, col) in enumerate(dv.cols)
            if !tab.attrisnulls[k]
                col = PlainColumn(col.vals)
            end
            push!(cols, col)
        end
        dv = DataVector(dv.len, cols)
        sqlctx[(uri, :tab, tab.sname, tab.name)] = dv
    end
    return sqlctx[(uri, :tab, tab.sname, tab.name)]::DataVector
end

