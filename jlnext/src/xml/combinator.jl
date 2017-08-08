
OpenXML(filename) =
    Lift(f -> parsexml(readstring(f)), convert(Combinator, filename))

XMLRoot() =
    Lift(getroot, It)

XMLRoot(name; kw...) =
    XMLRoot() >> ThenFilter(_xmlchildfilter(name; kw...))

XMLName() =
    Lift(getname, It)

LiftQuery{V}(fn, argtypes::Tuple{Vararg{Type}}, restype::Type{XMLElementVector{V}}, qs::Vector{Query}) =
    let q = invoke(LiftQuery, (Any, Tuple{Vararg{Type}}, Type, Vector{Query}), fn, argtypes, restype, qs)
        q >> Query(DecodeVectorSig(), Input(XMLElementVector{V}), Output(XMLElement) |> setoptional() |> setplural())
    end

XMLParent() =
    Lift(getparent, It)

XMLChild() =
    Lift(getchildren, It)

XMLChild(name; kw...) =
    XMLChild() >> ThenFilter(_xmlchildfilter(name; kw...))

XMLDescendant() =
    Lift(getdescendants, It)

XMLDescendant(name; kw...) =
    XMLDescendant() >> ThenFilter(_xmlchildfilter(name; kw...))

function _xmlchildfilter(name; kw...)
    C = XMLName() .== name
    for (k, v) in kw
        if v == true
            C = C & Exists(XMLAttribute(string(k)))
        elseif v == false
            C = C & ~Exists(XMLAttribute(string(k)))
        else
            C = C & (XMLAttribute(string(k)) .== v)
        end
    end
    C
end

XMLText() =
    Lift(gettext, It)

XMLAttribute(attr) =
    Lift(getattribute, It, convert(Combinator, attr))

