#
# The bare type of a database object or a value.
#

# Aliases and checks for the top, singleton and empty types.

typealias Unit Void
typealias Zero Union{}

isany(T::Type) = T == Any
isunit(T::Type) = T == Unit
iszero(T::Type) = T == Zero

# A domain is a value type, a nominal entity class, or a record.

immutable Domain
    desc    # ::Union{Type, Symbol, Tuple{Vararg{Output}}}

    function Domain(desc)
        if isa(desc, Tuple)
            desc = ((convert(Output, osig) for osig in desc)...)
        end
        new(desc::Union{Type, Symbol, Tuple{Vararg{Output}}})
    end
end

function show(io::IO, dom::Domain)
    if isentity(dom)
        print(io, dom.desc::Symbol)
    elseif isrecord(dom)
        print(io, "{")
        for (k, osig) in enumerate(dom.desc::Tuple{Vararg{Output}})
            if k > 1
                print(io, ", ")
            end
            print(io, osig)
        end
        print(io, "}")
    else
        desc = dom.desc::Type
        if isunit(desc)
            print(io, "Unit")
        elseif iszero(desc)
            print(io, "Zero")
        else
            print(io, desc)
        end
    end
end

# Predicates.

isdata(dom::Domain) = isa(dom.desc, Type)
isany(dom::Domain) = isdata(dom) && isany(dom.desc::Type)
isunit(dom::Domain) = isdata(dom) && isunit(dom.desc::Type)
iszero(dom::Domain) = isdata(dom) && iszero(dom.desc::Type)
isentity(dom::Domain) = isa(dom.desc, Symbol)
isrecord(dom::Domain) = isa(dom.desc, Tuple{Vararg{Output}})

# The native Julia type that can represent the domain values.

datatype(dom::Domain) =
    isentity(dom) ?
        Entity{dom.desc::Symbol} :
    isrecord(dom) ?
        Tuple{(datatype(osig) for osig in dom.desc::Tuple{Vararg{Output}})...} :
        dom.desc::Type

# The name of an entity class.

classname(dom::Domain) =
    isentity(dom) ? dom.desc::Symbol : Symbol("")

# A tuple of record fields.

fields(dom::Domain) =
    isrecord(dom) ?
        dom.desc::Tuple{Vararg{Output}} :
        (Output(dom),)

