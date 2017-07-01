
type XMLBuilder
    stk::Vector{Int}
    last::Int
    len::Int
    parent_offs::Vector{Int}
    parent_vals::Vector{Int}
    name_vals::Vector{String}
    attr_offs::Vector{Int}
    attr_vals::Vector{Pair{String,String}}
    itext_vals::Vector{String}
    otext_vals::Vector{String}
end

XMLBuilder() =
    XMLBuilder(Int[], 0, 0, Int[1], Int[], String[], Int[1], Pair{String,String}[], String[], String[])

function addelementstart!(b::XMLBuilder, name::String)
    b.len += 1
    if !isempty(b.stk)
        parent = b.stk[end]
        push!(b.parent_vals, parent)
    end
    push!(b.parent_offs, length(b.parent_vals)+1)
    push!(b.stk, b.len)
    b.last = 0
    push!(b.name_vals, name)
    push!(b.attr_offs, length(b.attr_vals)+1)
    push!(b.itext_vals, "")
    push!(b.otext_vals, "")
    nothing
end

function addelementend!(b::XMLBuilder)
    b.last = pop!(b.stk)
    nothing
end

function addattribute!(b::XMLBuilder, key::String, val::String)
    b.attr_offs[end] += 1
    push!(b.attr_vals, key => val)
    nothing
end

function addtext!(b::XMLBuilder, text::String)
    if b.last == 0
        if isempty(b.itext_vals[end])
            b.itext_vals[end] = text
        else
            b.itext_vals[end] *= text
        end
    else
        if isempty(b.otext_vals[b.last])
            b.otext_vals[b.last] = text
        else
            b.otext_vals[b.last] *= text
        end
    end
end

immutable XMLDocument
    len::Int
    parent::OptionalColumn{Vector{Int},Vector{Int}}
    child::PluralColumn{Vector{Int},Vector{Int}}
    name::PlainColumn{Base.OneTo{Int},Vector{String}}
    attr::PluralColumn{Vector{Int},Vector{Pair{String,String}}}
    itext::PlainColumn{Base.OneTo{Int},Vector{String}}
    otext::PlainColumn{Base.OneTo{Int},Vector{String}}
end

show(io::IO, doc::XMLDocument) =
    show(io, root(doc))

immutable XMLElement
    val::Int
    doc::XMLDocument
end

show(io::IO, el::XMLElement) =
    print(io, "<", getname(el), ">")

immutable XMLElementVector{V<:AbstractVector{Int}} <: AbstractVector{XMLElement}
    vals::V
    doc::XMLDocument
end

@inline size(ev::XMLElementVector) = size(ev.vals)
@inline length(ev::XMLElementVector) = length(ev.vals)
@inline getindex(ev::XMLElementVector, i::Int) = XMLElement(ev.vals[i], ev.doc)
@inline getindex(ev::XMLElementVector, idxs::AbstractVector{Int}) =
    XMLElementVector(ev.vals[idxs], ev.doc)
Base.array_eltype_show_how(::XMLElementVector) = (true, "")

getroot(doc::XMLDocument) =
    XMLElement(1, doc)

getname(el::XMLElement) =
    let cr = el.doc.name[el.val]
        cr[1]
    end

function getchildren(el::XMLElement, self::Bool=false)
    cr = el.doc.child[el.val]
    vals =
        if self
            vals = Int[el.val]
            append!(vals, cr)
            vals
        else
            collect(Int, cr)
        end
    return XMLElementVector(vals, el.doc)
end

function getdescendants(el::XMLElement, self::Bool=false)
    vals = Int[]
    if self
        push!(vals, el.val)
    end
    cr = el.doc.child[el.val]
    stk = Tuple{Int,Int}[]
    push!(stk, (el.val, 1))
    while !isempty(stk)
        val, pos = pop!(stk)
        move!(el.doc.child, cr, val)
        if pos <= length(cr)
            ch = cr[pos]
            push!(vals, ch)
            push!(stk, (val, pos+1))
            push!(stk, (ch, 1))
        end
    end
    return XMLElementVector(vals, el.doc)
end

function gettext(el::XMLElement)
    cr = el.doc.child[el.val]
    itextcr = el.doc.itext[el.val]
    if isempty(cr)
        return itextcr[1]
    end
    otextcr = el.doc.otext[el.val]
    text = String[itextcr[1]]
    stk = Tuple{Int,Int}[]
    push!(stk, (el.val, 1))
    while !isempty(stk)
        val, pos = pop!(stk)
        move!(el.doc.child, cr, val)
        if pos <= length(cr)
            ch = cr[pos]
            push!(stk, (val, pos+1))
            push!(stk, (ch, 1))
            move!(el.doc.itext, itextcr, ch)
            push!(text, itextcr[1])
        elseif !isempty(stk)
            move!(el.doc.otext, otextcr, val)
            push!(text, otextcr[1])
        end
    end
    return join(text)
end

function getattribute(el::XMLElement, attr::String)
    cr = el.doc.attr[el.val]
    for (aname, aval) in cr
        if aname == attr
            return Nullable{String}(aval)
        end
    end
    return Nullable{String}()
end

function build(b::XMLBuilder)
    len = b.len
    parent = OptionalColumn(b.parent_offs, b.parent_vals)
    size = fill(0, len)
    for parent_val in b.parent_vals
        size[parent_val] += 1
    end
    child_offs = Vector{Int}(len+1)
    child_vals = Vector{Int}(sum(size))
    child_offs[1] = 1
    for k = 1:len
        child_offs[k+1] = child_offs[k] + size[k]
    end
    child_idxs = child_offs[1:len]
    for k = 1:endof(b.parent_vals)
        parent_val = b.parent_vals[k]
        child_val = k+1
        child_vals[child_idxs[parent_val]] = child_val
        child_idxs[parent_val] += 1
    end
    child = PluralColumn(child_offs, child_vals)
    name = PlainColumn(b.name_vals)
    attr = PluralColumn(b.attr_offs, b.attr_vals)
    itext = PlainColumn(b.itext_vals)
    otext = PlainColumn(b.otext_vals)
    return XMLDocument(len, parent, child, name, attr, itext, otext)
end

function xmlcharacters(data::Ptr{Void}, str::Ptr{UInt8}, len::Int32)
    b = unsafe_pointer_to_objref(data)
    text = unsafe_string(str, len)
    addtext!(b, text)
    nothing
end

function xmlelementstart(data::Ptr{Void}, name::Ptr{UInt8}, atts::Ptr{Ptr{UInt8}})
    b = unsafe_pointer_to_objref(data)
    name = unsafe_string(name)
    addelementstart!(b, name)
    j = 1
    while unsafe_load(atts, j) != C_NULL && unsafe_load(atts, j+1) != C_NULL
        k = unsafe_string(unsafe_load(atts, j))
        v = unsafe_string(unsafe_load(atts, j+1))
        j += 2
        addattribute!(b, k, v)
    end
end

function xmlelementend(data::Ptr{Void}, name::Ptr{UInt8})
    b = unsafe_pointer_to_objref(data)
    addelementend!(b)
    nothing
end

function parsexml(text::String)
    p = XML_ParserCreateNS(C_NULL, 0x20)
    if p == C_NULL
        throw(OutOfMemoryError())
    end
    bld = XMLBuilder()
    xmlcharacters_c = cfunction(xmlcharacters, Void, (Ptr{Void}, Ptr{UInt8}, Int32))
    xmlelementstart_c = cfunction(xmlelementstart, Void, (Ptr{Void}, Ptr{UInt8}, Ptr{Ptr{UInt8}}))
    xmlelementend_c = cfunction(xmlelementend, Void, (Ptr{Void}, Ptr{UInt8}))
    XML_SetUserData(p, pointer_from_objref(bld))
    XML_SetElementHandler(p, xmlelementstart_c, xmlelementend_c)
    XML_SetCharacterDataHandler(p, xmlcharacters_c)
    status = XML_Parse(p, text, Int32(length(text)), Int32(1))
    if status != 1
        msg = unsafe_string(XML_ErrorString(UInt32(XML_GetErrorCode(p))))
        l = XML_GetCurrentLineNumber(p)
        c = XML_GetCurrentColumnNumber(p)+1
        XML_ParserFree(p)
        error("XML parsing failed at line $l, column $c: $msg")
    end
    XML_ParserFree(p)
    return build(bld)
end

