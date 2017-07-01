
OpenXML(filename) =
    Lift(f -> parsexml(readstring(f)), convert(Combinator, filename))

XMLRoot() =
    Lift(getroot, It)

XMLName() =
    Lift(getname, It)

LiftQuery{V}(fn, argtypes::Tuple{Vararg{Type}}, restype::Type{XMLElementVector{V}}, qs::Vector{Query}) =
    let q = invoke(LiftQuery, (Any, Tuple{Vararg{Type}}, Type, Vector{Query}), fn, argtypes, restype, qs)
        q >> Query(DecodeVectorSig(), Input(XMLElementVector{V}), Output(XMLElement) |> setoptional() |> setplural())
    end

XMLChild() =
    Lift(getchildren, It)

XMLChild(name) =
    XMLChild() >> ThenFilter(XMLName() .== name)

XMLDescendant() =
    Lift(getdescendants, It)

XMLDescendant(name) =
    XMLDescendant() >> ThenFilter(XMLName() .== name)

XMLText() =
    Lift(gettext, It)

XMLAttribute(attr) =
    Lift(getattribute, It, convert(Combinator, attr))

