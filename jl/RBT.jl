
__precompile__()

module RBT

export
    setdb,
    getdb,
    @q_str,
    query,
    @query

import Base:
    show, call, convert, get, isnull, isempty, length, eltype,
    start, next, done, endof, getindex, max, *, >>, ^


include("abstract.jl")
include("database.jl")
include("syntax.jl")
include("functor.jl")
include("pipe.jl")
include("scope.jl")
include("compile.jl")

try
    using DataFrames
    include("df.jl")
catch ArgumentError
end


global DB = Database(Schema(), Instance(Dict(), Dict()))

function setdb(db)
    global DB = db
end

function getdb()
    return DB
end


function query(state, expr; params...)
    params_signature = ([(name, typeof(param)) for (name, param) in params]...)
    return execute(prepare(state, expr; params_signature...); params...)
end

function query(expr; params...)
    return query(DB, expr; params...)
end

macro query(args...)
    L = endof(args)
    while L > 0 && isa(args[L], Expr) && args[L].head == :kw
        L = L-1
    end
    @assert 1 <= L <= 2
    if L == 2
        db, expr = args[1], args[2]
    else
        db, expr = DB, args[1]
    end
    expr = syntax(expr)
    params = args[L+1:end]
    return quote
        query($(esc(db)), $expr; $(params...))
    end
end

macro q_str(str)
    query(str)
end


function prepare(expr; params_signature...)
    return prepare(DB, expr; params_signature...)
end

macro prepare(args...)
    L = endof(args)
    while L > 0 && isa(args[L], Expr) && args[L].head == :kw
        L = L-1
    end
    @assert 1 <= L <= 2
    if L == 2
        db, expr = args[1], args[2]
    else
        db, expr = DB, args[1]
    end
    expr = syntax(expr)
    params = args[L+1:end]
    return quote
        prepare($(esc(db)), $expr; $(params...))
    end
end

end

