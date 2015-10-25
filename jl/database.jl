
immutable Entity{name}
    id::Int
end

classname{name}(::Type{Entity{name}}) = name
convert{name}(::Type{Entity{name}}, id::Int) = Entity{name}(id)
show{name}(io::IO, e::Entity{name}) = print(io, "<", name, ":", e.id, ">")


const SelectType = Union{Void, Symbol, Tuple{Vararg{Symbol}}}

immutable Arrow
    name::Symbol
    output::Output
    select::SelectType
end

Arrow(
    name::Symbol, T::DataType;
    singular=true, total=true, unique=false, reachable=false,
    select=nothing) =
    Arrow(name, Output(T, singular=singular, total=total, unique=unique, reachable=reachable), select)
Arrow(name::Symbol, targetname::Symbol; props...) =
    Arrow(name, Entity{target}; props...)
Arrow(name::Symbol; props...) =
    Arrow(name, Entity{name}; props...)

function show(io::IO, a::Arrow)
    T = domain(a.output)
    print(io, a.name, ": ", T <: Entity ? ucfirst(string(classname(T))) : T)
    features = []
    singular(a.output) || push!(features, :plural)
    total(a.output) || push!(features, :partial)
    !unique(a.output) || push!(features, :unique)
    !reachable(a.output) || push!(features, :reachable)
    if !isempty(features)
        print(io, " {", join(features, ", "), "}")
    end
end


immutable Class
    name::Symbol
    arrows::Dict{Symbol, Arrow}
    select::SelectType
end

Class(name::Symbol, as::Arrow...; select=nothing) = Class(name, Dict([a.name => a for a in as]), select)

function show(io::IO, c::Class)
    print(io, ucfirst(string(c.name)), ":")
    for a in values(c.arrows)
        print(io, "\n  ", a)
    end
end


immutable Schema
    classes::Dict{Symbol, Class}
end

Schema(cs::Class...) = Schema(Dict([c.name => c for c in cs]))

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

