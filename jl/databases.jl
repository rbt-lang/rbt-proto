
module Databases

import Base: convert, show

export
    Entity,
    Arrow,
    Class,
    Schema,
    Instance,
    Database,
    class


immutable Entity{name}
    id::Int
end

class{name}(::Type{Entity{name}}) = name
convert{name}(::Type{Entity{name}}, id::Int) = Entity{name}(id)
show{name}(io::IO, e::Entity{name}) = print(io, "<", name, ":", e.id, ">")


immutable Arrow
    name::Symbol
    T::DataType
    partial::Bool
    plural::Bool
    unique::Bool
end

Arrow(name::Symbol, T::DataType; partial=false, plural=false, unique=false) =
    Arrow(name, T, partial, plural, unique)
Arrow(name::Symbol, targetname::Symbol; partial=false, plural=false, unique=false) =
    Arrow(name, Entity{target}, partial, plural, unique)
Arrow(name::Symbol; partial=false, plural=false, unique=false) =
    Arrow(name, Entity{name}, partial, plural, unique)

function show(io::IO, a::Arrow)
    print(io, a.name, ": ", a.T <: Entity ? ucfirst(string(class(a.T))) : a.T)
    features = []
    for feature in [:partial, :plural, :unique]
        if getfield(a, feature)
            push!(features, feature)
        end
    end
    if !isempty(features)
        print(io, " {", join(features, ", "), "}")
    end
end

immutable Class
    name::Symbol
    arrows::Dict{Symbol, Arrow}
end

Class(name::Symbol, as::Arrow...) = Class(name, Dict(map(a -> a.name=>a, as)...))

function show(io::IO, c::Class)
    print(io, ucfirst(string(c.name)), ":")
    for a in values(c.arrows)
        print(io, "\n  ", a)
    end
end


immutable Schema
    classes::Dict{Symbol, Class}
end

Schema(cs::Class...) = Schema(Dict(map(c -> c.name=>c, cs)...))

function show(io::IO, s::Schema)
    fst = true
    for c in values(s.classes)
        if !fst
            print(io, "\n")
        end
        print(io, c)
        fst = false
    end
end


immutable Instance
    sets::Dict{Symbol, Vector{Entity}}
    maps::Dict{Tuple{Symbol, Symbol}, Dict}
end


immutable Database
    schema::Schema
    instance::Instance
end

show(io::IO, db::Database) = show(io, db.schema)

end

