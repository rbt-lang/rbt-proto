
abstract PGAbstractImage

type PGCatalog <: PGAbstractImage
    name2schema::Dict{String,UInt}

    PGCatalog() = new(Dict{String,UInt}())
end

type PGSchema <: PGAbstractImage
    name::String
    name2table::Dict{String,UInt}
    name2index::Dict{String,UInt}
    name2sequence::Dict{String,UInt}
    sig2procedure::Dict{Tuple{String,Tuple{Vararg{UInt}}},UInt}
    name2type::Dict{String,UInt}
    comment::Nullable{String}

    PGSchema(name) =
        new(name,
            Dict{String,UInt}(),
            Dict{String,UInt}(),
            Dict{String,UInt}(),
            Dict{Tuple{String,Tuple{Vararg{UInt}}},UInt}(),
            Dict{String,UInt}(),
            nothing)
end

type PGTable <: PGAbstractImage
    schema::UInt
    name::String
    columns::Vector{UInt}
    name2column::Dict{String,UInt}
    name2ukey::Dict{String,UInt}
    pkey::Nullable{UInt}
    name2fkey::Dict{String,UInt}
    rfkeys::Set{UInt}
    indexes::Set{UInt}
    name2trigger::Dict{String,UInt}
    comment::Nullable{String}

    PGTable(schema, name) =
        new(schema,
            name,
            UInt[],
            Dict{String,UInt}(),
            Dict{String,UInt}(),
            nothing,
            Dict{String,UInt}(),
            Set{UInt}(),
            Set{UInt}(),
            Dict{String,UInt}(),
            nothing)
end

type PGColumn <: PGAbstractImage
    table::UInt
    name::String
    type_::UInt
    isnull::Bool
    default::Nullable{String}
    ukeys::Set{UInt}
    fkeys::Set{UInt}
    rfkeys::Set{UInt}
    indexes::Set{UInt}
    sequences::Set{UInt}
    comment::Nullable{String}

    PGColumn(table, name, type_, isnull=false, default=nothing) =
        new(table,
            name,
            type_,
            isnull,
            default,
            Set{UInt}(),
            Set{UInt}(),
            Set{UInt}(),
            Set{UInt}(),
            Set{UInt}(),
            nothing)
end

type PGUniqueKey <: PGAbstractImage
    name::String
    table::UInt
    columns::Vector{UInt}
    isprimary::Bool
    indexes::Set{UInt}
    comment::Nullable{String}

    PGUniqueKey(name, table, columns, isprimary=false) =
        new(name,
            table,
            columns,
            isprimary,
            Set{UInt}(),
            nothing)
end

type PGForeignKey <: PGAbstractImage
    name::String
    table::UInt
    columns::Vector{UInt}
    rtable::UInt
    rcolumns::Vector{UInt}
    onupdate::String
    ondelete::String
    comment::Nullable{String}

    PGForeignKey(name, table, columns, rtable, rcolumns, onupdate="NO ACTION", ondelete="NO ACTION") =
        new(name,
            table,
            columns,
            rtable,
            rcolumns,
            onupdate,
            ondelete,
            nothing)
end

type PGIndex <: PGAbstractImage
    schema::UInt
    name::String
    table::UInt
    columns::Vector{UInt}
    ukey::Nullable{UInt}
    comment::Nullable{String}

    PGIndex(schema, name, table, columns) =
        new(schema,
            name,
            table,
            columns,
            nothing,
            nothing)
end

type PGSequence <: PGAbstractImage
    schema::UInt
    name::String
    column::Nullable{UInt}
    comment::Nullable{String}

    PGSequence(schema, name) =
        new(schema,
            name,
            nothing,
            nothing)
end

type PGProcedure <: PGAbstractImage
    schema::UInt
    name::String
    argtypes::Vector{UInt}
    restype::UInt
    source::String
    triggers::Set{UInt}
    comment::Nullable{String}

    PGProcedure(schema, name, argtypes, restype, source) =
        new(schema,
            name,
            argtypes,
            restype,
            source,
            Set{UInt}(),
            nothing)
end

type PGTrigger <: PGAbstractImage
    table::UInt
    name::String
    procedure::UInt
    comment::Nullable{String}

    PGTrigger(table, name, procedure) =
        new(table,
            name,
            procedure,
            nothing)
end

type PGType <: PGAbstractImage
    schema::UInt
    name::String
    enum::Nullable{Vector{String}}
    columns::Set{UInt}
    procedures::Set{UInt}
    comment::Nullable{String}

    PGType(schema, name, enum=nothing) =
        new(schema,
            name,
            enum,
            Set{UInt}(),
            Set{UInt}(),
            nothing)
end

type PGImageSet
    catalog::PGCatalog
    schemas::Dict{UInt,PGSchema}
    tables::Dict{UInt,PGTable}
    columns::Dict{UInt,PGColumn}
    ukeys::Dict{UInt,PGUniqueKey}
    fkeys::Dict{UInt,PGForeignKey}
    indexes::Dict{UInt,PGIndex}
    sequences::Dict{UInt,PGSequence}
    procedures::Dict{UInt,PGProcedure}
    triggers::Dict{UInt,PGTrigger}
    types::Dict{UInt,PGType}

    PGImageSet() =
        new(PGCatalog(),
            Dict{UInt,PGSchema}(),
            Dict{UInt,PGTable}(),
            Dict{UInt,PGColumn}(),
            Dict{UInt,PGUniqueKey}(),
            Dict{UInt,PGForeignKey}(),
            Dict{UInt,PGIndex}(),
            Dict{UInt,PGSequence}(),
            Dict{UInt,PGProcedure}(),
            Dict{UInt,PGTrigger}(),
            Dict{UInt,PGType}())
end

immutable PGImage{T}
    set::PGImageSet
    obj::T
end

convert(::Type{UInt}, img::PGImage) =
    object_id(img.obj)

convert(::Type{UInt}, obj::PGAbstractImage) =
    object_id(obj)

PGImage(::Type{PGCatalog}, set::PGImageSet) =
    PGImage{PGCatalog}(set, set.catalog)

newcatalog() =
    PGImage(PGCatalog, PGImageSet())

function addschema(catalog::PGImage{PGCatalog}, name::String)
    obj = PGSchema(name)
    oid = object_id(obj)
    catalog.set.schemas[oid] = obj
    catalog.obj.name2schema[obj.name] = oid
    PGImage(catalog.set, obj)
end

function addtable(schema::PGImage{PGSchema}, name::String)
    obj = PGTable(schema, name)
    oid = object_id(obj)
    schema.set.tables[oid] = obj
    schema.obj.name2table[obj.name] = oid
    PGImage(schema.set, obj)
end

function addtype(schema::PGImage{PGSchema}, name::String)
    obj = PGType(schema, name)
    oid = object_id(obj)
    schema.set.types[oid] = obj
    schema.obj.name2type[obj.name] = oid
    PGImage(schema.set, obj)
end

function addsequence(schema::PGImage{PGSchema}, name::String)
    obj = PGSequence(schema, name)
    oid = object_id(obj)
    schema.set.sequences[oid] = obj
    schema.obj.name2sequence[obj.name] = oid
    PGImage(schema.set, obj)
end

function addtype(schema::PGImage{PGSchema}, name::String, labels::Vector{String})
    obj = PGType(schema, name, labels)
    oid = object_id(obj)
    schema.set.types[oid] = obj
    schema.obj.name2type[obj.name] = oid
    PGImage(schema.set, obj)
end

function addprocedure(
        schema::PGImage{PGSchema}, name::String, argtypes::Vector{PGImage{PGType}}, restype::PGImage{PGType},
        source::String)
    argtypeids = [object_id(argtype.obj) for argtype in argtypes]
    obj = PGProcedure(schema, name, argtypeids, object_id(restype.obj), source)
    oid = object_id(obj)
    schema.set.procedures[oid] = obj
    schema.obj.sig2procedure[(name, (argtypeids...))] = oid
    for type_ in argtypes
        push!(type_.obj.procedures, oid)
    end
    push!(restype.obj.procedures, oid)
    PGImage(schema.set, obj)
end

function addcolumn(table::PGImage{PGTable}, name::String, type_::PGImage{PGType}, isnull::Bool)
    obj = PGColumn(table, name, type_, isnull)
    oid = object_id(obj)
    table.set.columns[oid] = obj
    table.obj.name2column[name] = oid
    push!(table.obj.columns, oid)
    push!(type_.obj.columns, oid)
    PGImage(table.set, obj)
end

function addindex(schema::PGImage{PGSchema}, name::String, table::PGImage{PGTable}, columns::Vector{PGImage{PGColumn}})
    columnids = [object_id(column.obj) for column in columns]
    obj = PGIndex(schema, name, table, columns)
    oid = object_id(obj)
    schema.set.indexes[oid] = obj
    schema.obj.name2index[name] = oid
    push!(table.obj.indexes, oid)
    for column in columns
        push!(column.obj.indexes, oid)
    end
    PGImage(schema.set, obj)
end

function adduniquekey(table::PGImage{PGTable}, name::String, columns::Vector{PGImage{PGColumn}}, isprimary::Bool)
    columnids = [object_id(column.obj) for column in columns]
    obj = PGUniqueKey(name, table, columnids, isprimary)
    oid = object_id(obj)
    table.set.ukeys[oid] = obj
    table.obj.name2ukey[name] = oid
    if isprimary
        table.obj.pkey = oid
    end
    for column in columns
        push!(column.obj.ukeys, oid)
    end
    PGImage(table.set, obj)
end

function addforeignkey(
        table::PGImage{PGTable}, name::String, columns::Vector{PGImage{PGColumn}},
        rtable::PGImage{PGTable}, rcolumns::Vector{PGImage{PGColumn}}, onupdate::String, ondelete::String)
    columnids = [object_id(column.obj) for column in columns]
    rcolumnids = [object_id(column.obj) for column in rcolumns]
    obj = PGForeignKey(name, table, columnids, rtable, rcolumnids, onupdate, ondelete)
    oid = object_id(obj)
    table.set.fkeys[oid] = obj
    table.obj.name2fkey[name] = oid
    push!(rtable.obj.rfkeys, oid)
    for column in columns
        push!(column.obj.fkeys, oid)
    end
    for column in rcolumns
        push!(column.obj.rfkeys, oid)
    end
    PGImage(table.set, obj)
end

function addtrigger(table::PGImage{PGTable}, name::String, procedure::PGImage{PGProcedure})
    obj = PGTrigger(table, name, procedure)
    oid = object_id(obj)
    table.set.triggers[oid] = obj
    table.obj.name2trigger[name] = oid
    push!(procedure.obj.triggers, oid)
    PGImage(table.set, obj)
end

function setindex(ukey::PGImage{PGUniqueKey}, index::PGImage{PGIndex})
    index.obj.ukey = ukey
    push!(ukey.obj.indexes, object_id(index.obj))
    index
end

function setdefault(column::PGImage{PGColumn}, default::String)
    column.obj.default = default
    column
end

function setcolumn(sequence::PGImage{PGSequence}, column::PGImage{PGColumn})
    sequence.obj.column = column
    push!(column.obj.sequences, object_id(sequence.obj))
    sequence
end

function setcomment(schema::PGImage{PGSchema}, comment::String)
    schema.obj.comment = comment
    schema
end

function setcomment(type_::PGImage{PGType}, comment::String)
    type_.obj.comment = comment
    type_
end

function setcomment(table::PGImage{PGTable}, comment::String)
    table.obj.comment = comment
    table
end

function setcomment(index::PGImage{PGIndex}, comment::String)
    index.obj.comment = comment
    index
end

function setcomment(sequence::PGImage{PGSequence}, comment::String)
    sequence.obj.comment = comment
    sequence
end

function setcomment(column::PGImage{PGColumn}, comment::String)
    column.obj.comment = comment
    column
end

function setcomment(ukey::PGImage{PGUniqueKey}, comment::String)
    ukey.obj.comment = comment
    ukey
end

function setcomment(fkey::PGImage{PGForeignKey}, comment::String)
    fkey.obj.comment = comment
    fkey
end

function setcomment(trigger::PGImage{PGTrigger}, comment::String)
    trigger.obj.comment = comment
    trigger
end

function introspect(conn::PGConnection)
    catalog = newcatalog()
    # Extract schemas.
    oid2schema = Dict{UInt32,PGImage{PGSchema}}()
    execute(conn, """
        SELECT n.oid, n.nspname
        FROM pg_catalog.pg_namespace n
        ORDER BY n.nspname
    """) do row
        oid, nspname = map(get, row)
        schema = addschema(catalog, nspname)
        oid2schema[oid] = schema
    end
    # Extract ENUM labels.
    oid2labels = Dict{UInt32,Vector{String}}()
    execute(conn, """
        SELECT e.enumtypid, e.enumlabel
        FROM pg_catalog.pg_enum e
        ORDER BY e.enumtypid, e.enumsortorder, e.oid
    """) do row
        enumtypid, enumlabel = map(get, row)
        if !(enumtypid in keys(oid2labels))
            oid2labels[enumtypid] = String[]
        end
        push!(oid2labels[enumtypid], enumlabel)
    end
    # Extract data types.
    oid2type = Dict{UInt32,PGImage{PGType}}()
    execute(conn, """
        SELECT t.oid, t.typnamespace, t.typname, t.typtype,
               t.typbasetype, t.typlen, t.typtypmod
        FROM pg_catalog.pg_type t
        ORDER BY t.typnamespace, t.typname
    """) do row
        oid, typnamespace, typname, typtype, typbasetype, typlen, typtypmod = map(get, row)
        schema = oid2schema[typnamespace]
        type_ =
            if typtype == 'e'
                labels = oid2labels[oid]
                addtype(schema, typname, labels)
            else
                addtype(schema, typname)
            end
        oid2type[oid] = type_
    end
    # Extract stored procedures.
    oid2procedure = Dict{UInt32,PGImage{PGProcedure}}()
    execute(conn, """
        SELECT p.oid, p.pronamespace, p.proname,
               p.proargtypes, p.prorettype, p.prosrc
        FROM pg_catalog.pg_proc p
        ORDER BY p.pronamespace, p.proname
    """) do row
        oid, pronamespace, proname, proargtypes, prorettype, prosrc = map(get, row)
        schema = oid2schema[pronamespace]
        argtypes = PGImage{PGType}[oid2type[proargtype] for proargtype in proargtypes]
        rettype = oid2type[prorettype]
        procedure = addprocedure(schema, proname, argtypes, rettype, prosrc)
        oid2procedure[oid] = procedure
    end
    # Extract tables.
    oid2table = Dict{UInt32,PGImage{PGTable}}()
    execute(conn, """
        SELECT c.oid, c.relnamespace, c.relname
        FROM pg_catalog.pg_class c
        WHERE c.relkind IN ('r', 'v') AND
              HAS_TABLE_PRIVILEGE(c.oid, 'SELECT')
        ORDER BY c.relnamespace, c.relname
    """) do row
        oid, relnamespace, relname = map(get, row)
        schema = oid2schema[relnamespace]
        table = addtable(schema, relname)
        oid2table[oid] = table
    end
    # Extract columns.
    num2column = Dict{Tuple{UInt32,Int16},PGImage{PGColumn}}()
    execute(conn, """
        SELECT a.attrelid, a.attnum, a.attname, a.atttypid, a.atttypmod,
               a.attnotnull, a.atthasdef, a.attisdropped
        FROM pg_catalog.pg_attribute a
        ORDER BY a.attrelid, a.attnum
    """) do row
        attrelid, attnum, attname, atttypid, atttypmod, attnotnull, atthasdef, attisdropped = map(get, row)
        if attisdropped
            return
        end
        if attname in ["tableoid", "cmax", "xmax", "cmin", "xmin", "ctid"]
            return
        end
        if !(attrelid in keys(oid2table))
            return
        end
        table = oid2table[attrelid]
        type_ = oid2type[atttypid]
        isnull = !attnotnull
        column = addcolumn(table, attname, type_, isnull)
        num2column[(attrelid, attnum)] = column
    end
    # Extract default values.
    execute(conn, """
        SELECT a.adrelid, a.adnum, pg_get_expr(a.adbin, a.adrelid)
        FROM pg_catalog.pg_attrdef a
        ORDER BY a.adrelid, a.adnum
    """) do row
        adrelid, adnum, adsrc = map(get, row)
        if (adrelid, adnum) in keys(num2column)
            column = num2column[(adrelid, adnum)]
            setdefault(column, adsrc)
        end
    end
    # Extract sequences.
    oid2sequence = Dict{UInt32,PGImage{PGSequence}}()
    execute(conn, """
        SELECT c.oid, c.relnamespace, c.relname
        FROM pg_catalog.pg_class c
        WHERE c.relkind = 'S'
        ORDER BY c.relnamespace, c.relname
    """) do row
        oid, relnamespace, relname = map(get, row)
        schema = oid2schema[relnamespace]
        sequence = addsequence(schema, relname)
        oid2sequence[oid] = sequence
    end
    # Associate sequences with the columns that own them.
    execute(conn, """
        SELECT d.objid, d.refobjid, d.refobjsubid
        FROM pg_catalog.pg_depend d
        JOIN pg_catalog.pg_class c
        ON (d.classid = 'pg_class'::regclass AND d.objid = c.oid)
        WHERE c.relkind = 'S' AND
              d.refclassid = 'pg_class'::regclass AND
              d.objsubid IS NOT NULL
        ORDER BY d.objid, d.refobjid, d.objsubid
    """) do row
        objid, refobjid, refobjsubid = map(get, row)
        sequence = oid2sequence[objid]
        column = num2column[(refobjid, refobjsubid)]
        setcolumn(sequence, column)
    end
    # Extract indexes.
    oid2index = Dict{UInt32,PGImage{PGIndex}}()
    execute(conn, """
        SELECT c.oid, c.relnamespace, c.relname, i.indrelid, i.indkey
        FROM pg_catalog.pg_class c
        JOIN pg_catalog.pg_index i
        ON (c.oid = i.indexrelid)
        WHERE c.relkind = 'i'
        ORDER BY c.relnamespace, c.relname
    """) do row
        oid, relnamespace, relname, indrelid, indkey = map(get, row)
        if !(indrelid in keys(oid2table))
            return
        end
        schema = oid2schema[relnamespace]
        table = oid2table[indrelid]
        columns = PGImage{PGColumn}[]
        for num in indkey
            if (indrelid, num) in keys(num2column)
                push!(columns, num2column[(indrelid, num)])
            end
        end
        index = addindex(schema, relname, table, columns)
        oid2index[oid] = index
    end
    # Extract unique keys.
    oid2ukey = Dict{UInt32,PGImage{PGUniqueKey}}()
    execute(conn, """
        SELECT c.oid, c.conname, c.contype, c.conrelid, c.conkey
        FROM pg_catalog.pg_constraint c
        WHERE c.contype IN ('p', 'u')
        ORDER BY c.oid
    """) do row
        oid, conname, contype, conrelid, conkey = map(get, row)
        if !(conrelid in keys(oid2table))
            return
        end
        table = oid2table[conrelid]
        columns = [num2column[(conrelid, num)] for num in conkey]
        isprimary = contype == 'p'
        key = adduniquekey(table, conname, columns, isprimary)
        oid2ukey[oid] = key
        schema = table.set.schemas[table.obj.schema]
        index = PGImage(table.set, table.set.indexes[schema.name2index[conname]])
        setindex(key, index)
    end
    # Extract foreign keys.
    oid2fkey = Dict{UInt32, PGImage{PGForeignKey}}()
    execute(conn, """
        SELECT c.oid, c.conname, c.conrelid, c.conkey,
               c.confrelid, c.confkey, c.confupdtype, c.confdeltype
        FROM pg_catalog.pg_constraint c
        WHERE c.contype = 'f'
        ORDER BY c.oid
    """) do row
        oid, conname, conrelid, conkey, confrelid, confkey, confupdtype, confdeltype = map(get, row)
        if !(conrelid in keys(oid2table)) || !(confrelid in keys(oid2table))
            return
        end
        table = oid2table[conrelid]
        columns = [num2column[(conrelid, num)] for num in conkey]
        rtable = oid2table[confrelid]
        rcolumns = [num2column[(confrelid, num)] for num in confkey]
        onupdate =
            confupdtype == 'a' ? "NO ACTION" :
            confupdtype == 'r' ? "RESTRICT" :
            confupdtype == 'c' ? "CASCADE" :
            confupdtype == 'n' ? "SET NULL" :
            confupdtype == 'd' ? "SET DEFAULT" : ""
        ondelete =
            confdeltype == 'a' ? "NO ACTION" :
            confdeltype == 'r' ? "RESTRICT" :
            confdeltype == 'c' ? "CASCADE" :
            confdeltype == 'n' ? "SET NULL" :
            confdeltype == 'd' ? "SET DEFAULT" : ""
        fkey = addforeignkey(table, conname, columns, rtable, rcolumns, onupdate, ondelete)
        oid2fkey[oid] = fkey
    end
    # Extract triggers.
    oid2trigger = Dict{UInt32,PGImage{PGTrigger}}()
    execute(conn, """
        SELECT t.oid, t.tgrelid, t.tgname, t.tgfoid
        FROM pg_catalog.pg_trigger AS t
        WHERE NOT t.tgisinternal
        ORDER BY t.tgrelid, t.tgname
    """) do row
        oid, tgrelid, tgname, tgfoid = map(get, row)
        table = oid2table[tgrelid]
        procedure = oid2procedure[tgfoid]
        trigger = addtrigger(table, tgname, procedure)
        oid2trigger[oid] = trigger
    end
    # Extract comments.
    execute(conn, """
        SELECT c.relname, d.objoid, d.objsubid, d.description
        FROM pg_catalog.pg_description d
        JOIN pg_catalog.pg_class c
        ON (d.classoid = c.oid)
        WHERE d.classoid IN ('pg_catalog.pg_namespace'::regclass,
                             'pg_catalog.pg_type'::regclass,
                             'pg_catalog.pg_proc'::regclass,
                             'pg_catalog.pg_class'::regclass,
                             'pg_catalog.pg_constraint'::regclass,
                             'pg_catalog.pg_trigger'::regclass)
        ORDER BY d.objoid, d.classoid, d.objsubid
    """) do row
        relname, objoid, objsubid, description = map(get, row)
        if relname == "pg_namespace"
            schema = oid2schema[objoid]
            setcomment(schema, description)
        elseif relname == "pg_type"
            type_ = oid2type[objoid]
            setcomment(type_, description)
        elseif relname == "pg_class" && objsubid == 0 && objoid in keys(oid2table)
            table = oid2table[objoid]
            setcomment(table, description)
        elseif relname == "pg_class" && objsubid == 0 && objoid in keys(oid2index)
            index = oid2index[objoid]
            setcomment(index, description)
        elseif relname == "pg_class" && objsubid == 0 && objoid in keys(oid2sequence)
            sequence = oid2sequence[objoid]
            setcomment(sequence, description)
        elseif relname == "pg_class" && (objoid, objsubid) in keys(num2column)
            column = num2column[(objoid, objsubid)]
            setcomment(column, description)
        elseif relname == "pg_constraint" && objoid in keys(oid2ukey)
            ukey = oid2ukey[objoid]
            setcomment(ukey, description)
        elseif relname == "pg_constraint" && objoid in keys(oid2fkey)
            fkey = oid2fkey[objoid]
            setcomment(fkey, description)
        elseif relname == "pg_trigger" && objoid in keys(oid2trigger)
            trigger = oid2trigger[objoid]
            setcomment(trigger, description)
        end
    end
    return catalog
end

