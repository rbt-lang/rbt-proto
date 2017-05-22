
type PGConnection
    conn::Ptr{PGconn}
    closed::Bool
    busy::Bool
end

immutable PGTypeOID{tid}
end

adapt(tid) =
    let X = PGTypeOID{tid}
        method_exists(adapttype, (Type{X},)) ? adapttype(X) : String
    end

adapt(tid, vals::Vector{String}) =
    let X = PGTypeOID{tid}
        if method_exists(adapttype, (Type{X},))
            adapt(X, vals)
        else
            vals
        end
    end

function adapt{N}(X::Type{PGTypeOID{N}}, vals::Vector{String})
    T = adapttype(X)
    ovals = Vector{T}(length(vals))
    for k in eachindex(vals)
        ovals[k] = adaptval(X, vals[k])
    end
    return ovals
end

adapttype(::Type{PGTypeOID{0x00000010}}) = Bool
adapttype(::Type{PGTypeOID{0x00000012}}) = Char
adapttype(::Type{PGTypeOID{0x00000014}}) = Int64
adapttype(::Type{PGTypeOID{0x00000015}}) = Int16
adapttype(::Type{PGTypeOID{0x00000016}}) = Vector{Int16}
adapttype(::Type{PGTypeOID{0x00000017}}) = Int32
adapttype(::Type{PGTypeOID{0x0000001a}}) = UInt32
adapttype(::Type{PGTypeOID{0x0000001e}}) = Vector{UInt32}
adapttype(::Type{PGTypeOID{0x000003ed}}) = Vector{Int16}

adaptval{N}(X::Type{PGTypeOID{N}}, text::String) = parse(adapttype(X), text)

adaptval(::Type{PGTypeOID{0x00000010}}, text::String) =
    text == "t" ? true : text == "f" ? false : error()

adaptval(::Type{PGTypeOID{0x00000012}}, text::String) = text[1]

adaptval(::Type{PGTypeOID{0x00000016}}, text::String) =
    Int16[parse(Int16, word) for word in split(text)]

adaptval(::Type{PGTypeOID{0x0000001e}}, text::String) =
    UInt32[parse(UInt32, word) for word in split(text)]

adaptval(::Type{PGTypeOID{0x000003ed}}, text::String) =
    Int16[parse(Int16, word) for word in split(strip(text, ['{','}']), ',')]

function getresult(res)
    ntuples = PQntuples(res)
    nfields = PQnfields(res)
    out = Array{String}(ntuples, nfields)
    for i = 1:ntuples
        for j = 1:nfields
            val = unsafe_string(PQgetvalue(res, Int32(i-1), Int32(j-1)))
            out[i,j] = val
        end
    end
    flows = Vector{OutputFlow}(nfields)
    for j = 1:nfields
        tag  = Symbol(unsafe_string(PQfname(res, Int32(j-1))))
        tid = PQftype(res, Int32(j-1))
        nnulls = 0
        for i = 1:ntuples
            if PQgetisnull(res, Int32(i-1), Int32(j-1)) == 1
                nnulls += 1
            end
        end
        col =
            if nnulls == 0
                vals = Vector{String}(ntuples)
                for i = 1:ntuples
                    val = unsafe_string(PQgetvalue(res, Int32(i-1), Int32(j-1)))
                    vals[i] = val
                end
                Column(1:ntuples+1, adapt(tid, vals))
            elseif nnulls == ntuples
                Column(fill(1, ntuples+1), adapt(tid, String[]))
            else
                offs = Vector{Int}(ntuples+1)
                vals = Vector{String}(ntuples-nnulls)
                offs[1] = 1
                n = 1
                for i = 1:ntuples
                    if PQgetisnull(res, Int32(i-1), Int32(j-1)) == 0
                        val = unsafe_string(PQgetvalue(res, Int32(i-1), Int32(j-1)))
                        vals[n] = val
                        n += 1
                    end
                    offs[i+1] = n
                end
                Column(offs, adapt(tid, vals))
            end
        flow = OutputFlow(Output(adapt(tid)) |> setoptional() |> decorate(:tag => tag) |> decorate(:tid => tid), col)
        flows[j] = flow
    end
    return DataSet(Int64(ntuples), flows)
end

function connect(uri)
    pgconn = PQconnectStart(uri)
    if pgconn == C_NULL
        throw(OutOfMemoryError())
    end
    if PQstatus(pgconn) == CONNECTION_BAD
        err = unsafe_string(PQerrorMessage(pgconn))
        PQfinish(pgconn)
        error("Connection to database failed: $err")
    end
    fd = RawFD(PQsocket(pgconn))
    status = PGRES_POLLING_WRITING
    while status == PGRES_POLLING_WRITING || status == PGRES_POLLING_READING
        if status == PGRES_POLLING_WRITING
            poll_fd(fd, writable=true)
        end
        if status == PGRES_POLLING_READING
            poll_fd(fd, readable=true)
        end
        status = PQconnectPoll(pgconn)
    end
    if status != PGRES_POLLING_OK
        err = unsafe_string(PQerrorMessage(pgconn))
        PQfinish(pgconn)
        error("Connection to database failed: $err")
    end
    conn = PGConnection(pgconn, false, false)
    finalizer(conn, disconnect)
    return conn
end

function execute(conn::PGConnection, sql::String)
    if conn.closed
        error("Connection is already closed")
    end
    if conn.busy
        error("Connection is busy")
    end
    conn.busy = true
    if PQsendQuery(conn.conn, sql) != 1
        conn.busy = false
        err = unsafe_string(PQerrorMessage(conn.conn))
        error("Sending query failed: $err")
    end
    fd = RawFD(PQsocket(conn.conn))
    while PQisBusy(conn.conn) != 0
        poll_fd(fd, readable=true)
        if PQconsumeInput(conn.conn) != 1
            conn.busy = false
            err = unsafe_string(PQerrorMessage(conn.conn))
            error("Consuming input failed: $err")
        end
    end
    done = false
    out = nothing
    while !done
        res = PQgetResult(conn.conn)
        if res != C_NULL
            status = PQresultStatus(res)
            if status == PGRES_TUPLES_OK
                out = getresult(res)
            elseif status != PGRES_EMPTY_QUERY && status != PGRES_COMMAND_OK
                err = unsafe_string(PQerrorMessage(conn.conn))
                PQclear(res)
                res = PQgetResult(conn.conn)
                while res != C_NULL
                    PQclear(res)
                    res = PQgetResult(conn.conn)
                end
                conn.busy = false
                error("Reading result failed: $err")
            end
            PQclear(res)
        else
            done = true
        end
    end
    conn.busy = false
    return out
end

function disconnect(conn::PGConnection)
    if !conn.closed
        PQfinish(conn.conn)
    end
    conn.closed = true
    nothing
end

