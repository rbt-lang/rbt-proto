
__precompile__()

module RBT

export
    setdb,
    getdb,
    @q_str,
    query,
    @query

import Base: show, call, convert, max, >>


include("abstract.jl")
include("database.jl")
include("syntax.jl")
include("pipe.jl")
include("scope.jl")
include("compile.jl")


global DB = Database(Schema(), Instance(Dict(), Dict()))

function setdb(db)
    global DB = db
end

function getdb()
    return DB
end


function query(state, expr)
    return execute(prepare(state, expr))
end

function query(expr)
    return query(DB, expr)
end

macro query(args...)
    @assert 1 <= length(args) <= 2
    if length(args) == 2
        db, expr = args
    else
        db, expr = DB, args[1]
    end
    expr = syntax(expr)
    return quote
        query($(esc(db)), $expr)
    end
end

macro q_str(str)
    query(str)
end


function prepare(expr)
    return prepare(DB, expr)
end

macro prepare(args...)
    @assert 1 <= length(args) <= 2
    if length(args) == 2
        db, expr = args
    else
        db, expr = DB, args[1]
    end
    expr = syntax(expr)
    return quote
        prepare($(esc(db)), $expr)
    end
end

end

