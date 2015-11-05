
immutable Entity{name}
    id::Int
end

classname{name}(::Type{Entity{name}}) = name
convert{name}(::Type{Entity{name}}, id::Int) = Entity{name}(id)
show{name}(io::IO, e::Entity{name}) = print(io, "<", name, ":", e.id, ">")


const SelectType = Union{Void, Symbol, Tuple{Vararg{Symbol}}}
const InverseType = Union{Void, Symbol}

immutable Arrow
    name::Symbol
    output::Output
    select::SelectType
    inverse::InverseType
end

Arrow(
    name::Symbol, T::DataType;
    singular=true, complete=true, exclusive=false, reachable=false,
    select=nothing, inverse=nothing) =
    Arrow(name, Output(T, OutputMode(singular, complete, exclusive, reachable)), select, inverse)
Arrow(name::Symbol, targetname::Symbol; props...) =
    Arrow(name, Entity{targetname}; props...)
Arrow(name::Symbol; props...) =
    Arrow(name, Entity{name}; props...)

function show(io::IO, a::Arrow)
    T = domain(a.output)
    print(io, a.name, ": ", T <: Entity ? ucfirst(string(classname(T))) : T)
    features = []
    inv = false
    if (a.output.domain <: Entity && a.inverse != nothing)
        push!(features, "inverse of $(classname(a.output.domain)).$(a.inverse)")
        inv = true
    end
    o = a.output
    singular(o) != inv || push!(features, singular(o) ? "singular" : "plural")
    complete(o) != inv || push!(features, complete(o) ? "complete" : "partial")
    exclusive(o) == inv || push!(features, exclusive(o) ? "exclusive" : "inexclusive")
    reachable(o) == inv || push!(features, reachable(o) ? "reachable" : "unreachable")
    if !isempty(features)
        print(io, " {", join(features, ", "), "}")
    end
end


immutable Class
    name::Symbol
    arrows::Tuple{Vararg{Arrow}}
    name2arrow::Dict{Symbol,Arrow}
    select::SelectType
end

Class(name::Symbol, as::Arrow...; select=nothing) =
    Class(name, as, Dict{Symbol,Arrow}([a.name => a for a in as]), select)

function show(io::IO, c::Class)
    print(io, ucfirst(string(c.name)), ":")
    for a in c.arrows
        print(io, "\n  ", a)
    end
end


immutable Schema
    classes::Tuple{Vararg{Class}}
    name2class::Dict{Symbol,Class}
end

Schema(cs::Class...) =
    Schema(cs, Dict{Symbol,Class}([c.name => c for c in cs]))

function show(io::IO, s::Schema)
    fst = true
    for c in s.classes
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

