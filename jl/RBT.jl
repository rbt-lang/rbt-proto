
module RBT

include("databases.jl")
include("pipes.jl")
include("parse.jl")
include("compile.jl")

import .Databases: Entity, Arrow, Class, Schema, Instance, Database, classname
import .Parse: query
import .Compile: compile

import Base: fetch

export
    setdb,
    @q_str,
    query,
    fetch,
    @fetch


global DB = nothing

function setdb(db)
    global DB = db
end


macro q_str(str)
    query(str)
end


function fetch(db::Database, q)
    flow = compile(db, q)
    return flow.pipe(())
end


macro fetch(db, q...)
    @assert length(q) <= 1
    if isempty(q)
        db, q = DB, db
    else
        q = q[1]
    end
    local syn = query(string("(", q, ")"))
    return quote
        fetch($(esc(db)), $syn)
    end
end

end

