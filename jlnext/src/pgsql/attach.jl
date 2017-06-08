
attach!(uri::String) = attach!(DB, uri)

toattrname(name::String) =
    Symbol(endswith(name, "_id") ? rstrip(name[1:end-2], '_') : name)

function attach!(db::Database, uri::String)
    id2tab = Dict{UInt,SQLTable}()
    conn = connect(uri)
    pg = introspect(conn)
    set = pg.set
    catalog = pg.obj
    disconnect(conn)
    schema_id = catalog.name2schema["public"]
    schema = set.schemas[schema_id]
    for table_id in values(schema.name2table)
        table = set.tables[table_id]
        sname = "public"
        name = table.name
        nattrs = 0
        attrnames = String[]
        attrtypes = Type[]
        attrisnulls = Bool[]
        attruniques = Bool[]
        for column_id in table.columns
            column = set.columns[column_id]
            type_ = set.types[column.type_]
            attrtype =
                if type_.name == "bool"
                    Bool
                elseif type_.name == "int4"
                    Int32
                elseif type_.name == "int8"
                    Int64
                else
                    String
                end
            attrunique = false
            for ukey_id in column.ukeys
                ukey = set.ukeys[ukey_id]
                if length(ukey.columns) == 1
                    attrunique = true
                end
            end
            nattrs += 1
            push!(attrnames, column.name)
            push!(attrtypes, attrtype)
            push!(attrisnulls, column.isnull)
            push!(attruniques, attrunique)
        end
        sortattrs = Int[]
        if !isnull(table.pkey)
            pkey_id = get(table.pkey)
            pkey = set.ukeys[pkey_id]
            for column_id in pkey.columns
                sortattr = findfirst(table.columns, column_id)
                push!(sortattrs, sortattr)
            end
        end
        id2tab[table_id] = SQLTable(sname, name, nattrs, attrnames, attrtypes, attrisnulls, attruniques, sortattrs)
    end
    for table_id in values(schema.name2table)
        table = set.tables[table_id]
        tab = id2tab[table_id]
        tfmt = Symbol[]
        for attrname in tab.attrnames
            push!(tfmt, toattrname(attrname))
        end
        tab_name = Symbol(tab.name)
        attach!(
            db,
            tab_name,
            SQLCollectionQuery(uri, tab, [Decoration(:tag, tab_name), Decoration(:fmt, tfmt)]))
        for attr in 1:tab.nattrs
            column_id = table.columns[attr]
            column = set.columns[column_id]
            attrname = toattrname(tab.attrnames[attr])
            if any(length(set.fkeys[fkey_id].columns) == 1 for fkey_id in column.fkeys)
                for fkey_id in column.fkeys
                    fkey = set.fkeys[fkey_id]
                    if length(fkey.columns) != 1
                        continue
                    end
                    rtable = set.tables[fkey.rtable]
                    rtab = id2tab[fkey.rtable]
                    rattr = findfirst(rtable.columns, fkey.rcolumns[1])
                    fmt = nothing
                    if !isnull(rtable.pkey)
                        rpkey = set.ukeys[get(rtable.pkey)]
                        fmt = Symbol[toattrname(rtab.attrnames[findfirst(rtable.columns, rcol)]) for rcol in rpkey.columns]
                    end
                    attach!(
                        db,
                        attrname,
                        SQLLinkQuery(uri, tab, attr, rtab, rattr, [Decoration(:tag, attrname), Decoration(:fmt, fmt)]))
                    rattrname = Symbol(table.name)
                    card = (count(rfk -> set.fkeys[rfk].table == table_id, rtable.rfkeys) +
                            count(c -> toattrname(set.columns[c].name) == rattrname, rtable.columns))
                    if card > 1
                        rattrname = Symbol(table.name, "_via_", attrname)
                    end
                    attach!(
                        db,
                        rattrname,
                        SQLLinkQuery(uri, rtab, rattr, tab, attr, [Decoration(:tag, rattrname), Decoration(:fmt, tfmt)]))
                    break
                end
            else
                attach!(
                    db,
                    Symbol(attrname),
                    SQLFieldQuery(uri, tab, attr, [Decoration(:tag, attrname)]))
            end
        end
    end
end

