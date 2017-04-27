#
# The bare type of a value or an object in the database.
#

# Aliases for special data types.

typealias Unit Void
typealias Zero Union{}

# Domain decorations.

typealias Decoration Pair{Symbol,Any}
typealias Decorations Vector{Decoration}

const NO_DECORATIONS = Decoration[]

function decoration{T}(decors::Decorations, name::Symbol, ::Type{T}, default::T)
    for (n, v) in decors
        if n == name && isa(v, T)
            return v::T
        end
    end
    return default
end

function decorate(decors::Decorations, d::Decoration)
    decors = copy(decors)
    for k in eachindex(decors)
        n = decors[k].first
        if n >= d.first
            if n == d.first
                decors[k] = d
            else
                insert!(decors, k, d)
            end
            return decors
        end
    end
    push!(decors, d)
    return decors
end

decorate(d::Decoration) =
    decors -> decorate(decors, d)

decorate(d::Pair{Symbol}) =
    decorate(Decoration(d.first, d.second))

# A domain is a value type, a nominal entity class, or a record.

immutable Domain
    desc    # ::Union{Type, Symbol, Vector{Output}}
    decors::Decorations

    Domain(desc::Union{Type, Symbol}, decors::Decorations=NO_DECORATIONS) =
        new(desc, decors)

    Domain(desc::Vector, decors::Decorations=NO_DECORATIONS) =
        new(convert(Vector{Output}, desc), decors)
end

convert(::Type{Domain}, desc::Union{Type, Symbol}) =
    Domain(desc)

function show(io::IO, dom::Domain)
    if isdata(dom)
        T = datatype(dom)
        if isunit(T)
            print(io, "Unit")
        elseif iszero(T)
            print(io, "Zero")
        else
            print(io, T)
        end
    elseif isentity(dom)
        print(io, classname(dom))
    elseif isrecord(dom)
        print(io, "{")
        comma = false
        for otype in fields(dom)
            if comma
                print(io, ", ")
            end
            comma = true
            print(io, otype)
        end
        print(io, "}")
    end
    decors = decorations(dom)
    if !isempty(decors)
        print(io, "[")
        comma = false
        for (n, v) in decors
            if comma
                print(io, ", ")
            end
            comma = true
            print(io, n, "=")
            if v !== nothing
                show(io, v)
            else
                print(io, "?")
            end
        end
        print(io, "]")
    end
end

# Decorations.

decorations(dom::Domain) = dom.decors

decoration(dom::Domain, name, T, default) =
    decoration(dom.decors, name, T, default)

decorate(dom::Domain, d::Decoration) =
    Domain(dom.desc, decorate(dom.decors, d))

# The domain kind.

isdata(dom::Domain) = isdata(dom.desc)
isany(dom::Domain) = isany(dom.desc)
isunit(dom::Domain) = isunit(dom.desc)
iszero(dom::Domain) = iszero(dom.desc)
isentity(dom::Domain) = isentity(dom.desc)
isrecord(dom::Domain) = isrecord(dom.desc)

isdata(desc::Type) = true
isany(desc::Type) = desc == Any
isunit(desc::Type) = desc == Unit
iszero(desc::Type) = desc == Zero
isentity(desc::Type) = false
isrecord(desc::Type) = false

isdata(desc::Symbol) = false
isany(desc::Symbol) = false
isunit(desc::Symbol) = false
iszero(desc::Symbol) = false
isentity(desc::Symbol) = true
isrecord(desc::Symbol) = false

# The native Julia type that can represent the domain values.

datatype(dom::Domain) = datatype(dom.desc)
datatype(desc::Type) = desc
datatype(desc::Symbol) = Entity{desc}

# The name of an entity class.

const NO_CLASSNAME = Symbol("")

classname(dom::Domain) = classname(dom.desc)
classname(desc::Type) = NO_CLASSNAME
classname(desc::Symbol) = desc

# List of record fields.

fields(dom::Domain) = fields(dom.desc)

