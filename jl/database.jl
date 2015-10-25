
immutable Entity{name}
    id::Int
end

classname{name}(::Type{Entity{name}}) = name
convert{name}(::Type{Entity{name}}, id::Int) = Entity{name}(id)
show{name}(io::IO, e::Entity{name}) = print(io, "<", name, ":", e.id, ">")


const SelectType = Union{Void, Symbol, Tuple{Vararg{Symbol}}}

immutable Arrow
    name::Symbol
    T::DataType
    singular::Bool
    total::Bool
    unique::Bool
    reachable::Bool
    select::SelectType
end

Arrow(name::Symbol, T::DataType; singular=true, total=true, unique=false, reachable=false, select=nothing) =
    Arrow(name, T, singular, total, unique, reachable, select)
Arrow(name::Symbol, targetname::Symbol; singular=true, total=true, unique=false, reachable=false, select=nothing) =
    Arrow(name, Entity{target}, singular, total, unique, reachable, select)
Arrow(name::Symbol; singular=true, total=true, unique=false, reachable=false, select=nothing) =
    Arrow(name, Entity{name}, singular, total, unique, reachable, select)

function show(io::IO, a::Arrow)
    print(io, a.name, ": ", a.T <: Entity ? ucfirst(string(classname(a.T))) : a.T)
    features = []
    a.singular || push!(features, :plural)
    a.total || push!(features, :partial)
    !a.unique || push!(features, :unique)
    !a.reachable || push!(features, :reachable)
    if !isempty(features)
        print(io, " {", join(features, ", "), "}")
    end
end


immutable Class
    name::Symbol
    arrows::Dict{Symbol, Arrow}
    select::SelectType
end

Class(name::Symbol, as::Arrow...; select=nothing) = Class(name, Dict(map(a -> a.name=>a, as)...), select)

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


immutable Database <: AbstractDatabase
    schema::Schema
    instance::Instance
end

show(io::IO, db::Database) = show(io, db.schema)

