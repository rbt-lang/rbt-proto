
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
    @q_str,
    query,
    fetch


macro q_str(str)
    query(str)
end


function fetch(db::Database, q)
    flow = compile(db, q)
    return flow.pipe(())
end

end

