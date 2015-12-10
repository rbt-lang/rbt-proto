#
# A toy database backend.
#


abstract AbstractDatabase


#
# An opaque unit of data such as an object, a person or a thing.
#

immutable Entity{name}
    id::Int
end

isentity{name}(::Type{Entity{name}}) = true
isentity(::Type) = false
classname{name}(::Type{Entity{name}}) = name
convert{name}(::Type{Entity{name}}, id::Int) = Entity{name}(id)
show{name}(io::IO, e::Entity{name}) = print(io, typeof(e), "(", e.id, ")")
show{name}(io::IO, ::Type{Entity{name}}) = print(io, ucfirst(string(name)))


#
# Describes an attribute or a relation defined on a class of entities.
#

const SelectType = Union{Void, Symbol, Tuple{Vararg{Symbol}}}
const InverseType = Union{Void, Symbol}

immutable Arrow
    name::Symbol
    output::Output
    select::SelectType
    inverse::InverseType
end

Arrow(
    name::Symbol, domain::Type;
    lunique=true, ltotal=true, runique=false, rtotal=false,
    select=nothing, inverse=nothing) =
    Arrow(name, Output(domain, OutputMode(lunique, ltotal, runique, rtotal)), select, inverse)
Arrow(name::Symbol, targetname::Symbol; props...) =
    Arrow(name, Entity{targetname}; props...)
Arrow(name::Symbol; props...) =
    Arrow(name, Entity{name}; props...)

output(a::Arrow) = a.output

show(io::IO, a::Arrow) =
    print(io,
        a.name,
        a.inverse != nothing ? " (inverse of $(odomain(a)).$(a.inverse))" : "",
        " :: ", a.output)


#
# Describes a group of homogeneous entities.
#

immutable Class
    name::Symbol
    arrows::Vector{Arrow}
    select::SelectType
    name2arrow::Dict{Symbol,Arrow}
end

Class(name::Symbol, as::Arrow...; select=nothing) =
    Class(name, collect(Arrow, as), select, Dict{Symbol,Arrow}([a.name => a for a in as]))

show(io::IO, c::Class) =
    begin
        print(io, Entity{c.name}, ":")
        for a in c.arrows
            print(io, "\n  ", a)
        end
    end


#
# All the classes in the database.
#

immutable Schema
    classes::Vector{Class}
    name2class::Dict{Symbol,Class}
end

Schema(cs::Class...) =
    Schema(collect(Class, cs), Dict{Symbol,Class}([c.name => c for c in cs]))

show(io::IO, s::Schema) = print_joined(io, s.classes, "\n")


#
# Data for a specific database instance.  In the toy backend,
# we keep all data in memory.
#

immutable Instance
    sets::Dict{Symbol, Vector}
    maps::Dict{Tuple{Symbol, Symbol}, Dict}
end


immutable ToyDatabase <: AbstractDatabase
    schema::Schema
    instance::Instance
end

show(io::IO, db::ToyDatabase) = show(io, db.schema)

