#
# An anonymous composite type with the given fields.
#

abstract AbstractRecord

function recordtype(fields::Vector{Symbol})
    namebuf = IOBuffer()
    print(namebuf, "Record")
    for field in fields
        print(namebuf, "#")
        print(namebuf, field)
    end
    name = Symbol(String(namebuf))
    if isdefined(RBT, name)
        return getfield(RBT, name)
    end
    typeline = []
    valline = []
    first = true
    for field in fields
        if !first
            push!(typeline, ", ")
            push!(valline, ", ")
        end
        first = false
        push!(typeline, "$field")
        push!(typeline, :( let T = fieldtype(R, $(QuoteNode(field))); !isa(T, TypeVar) ? "::$T" : ""; end ))
        push!(valline, "$field")
        push!(valline, :( let T = fieldtype(R, $(QuoteNode(field))); typeof(r.$field) != T ? "::$T" : ""; end ))
        push!(valline, " = ")
        push!(valline, :( repr(r.$field) ))
    end
    ex = Expr(
            :block,
            Expr(
                :type,
                false,
                Expr(
                    :(<:),
                    Expr(
                        :curly,
                        name,
                        (Symbol("T", k) for k in eachindex(fields))...),
                    AbstractRecord),
                Expr(
                     :block,
                     (Expr(:(::), field, Symbol("T", k)) for (k, field) in enumerate(fields))...)),
            Expr(
                :(=),
                :( Base.show{R<:$name}(io::IO, ::Type{R}) ),
                :( print(io, "@Record(", $(typeline...), ")") )),
            Expr(
                :(=),
                :( Base.show{R<:$name}(io::IO, r::R) ),
                :( print(io, "@Record(", $(valline...), ")") )))
    eval(RBT, ex)
    return getfield(RBT, name)
end

macro Record(args...)
    nargs = length(args)
    hastypes = false
    hasexprs = false
    fieldnames = Vector{Symbol}(nargs)
    fieldtypes = Vector{Any}(nargs)
    fieldexprs = Vector{Any}(nargs)
    seen = Set{Symbol}()
    for k in 1:nargs
        arg = args[k]
        if isa(arg, Expr) && arg.head == :(kw) && length(arg.args) == 2
            hasexprs = true
            fieldexprs[k] = arg.args[2]
            arg = arg.args[1]
        else
            fieldexprs[k] = nothing
        end
        if isa(arg, Expr) && arg.head == :(::) && length(arg.args) == 2
            hastypes = true
            fieldtypes[k] = arg.args[2]
            arg = arg.args[1]
        else
            fieldtypes[k] = Any
        end
        @assert isa(arg, Symbol) "ill-formed record field ($arg)"
        @assert !(arg in seen) "duplicate field name ($arg)"
        fieldnames[k] = arg
        push!(seen, arg)
    end
    ex = recordtype(fieldnames)
    if hastypes
        ex = Expr(:curly, ex, fieldtypes...)
    end
    if hasexprs
        ex = Expr(:call, ex, fieldexprs...)
    end
    return ex
end

@generated function fieldtypes{R<:AbstractRecord}(::Type{R})
    L = nfields(R)
    Ts = Vector{Type}(L)
    for k = 1:L
        T = fieldtype(R, k)
        Ts[k] = !isa(T, TypeVar) ? T : Any
    end
    return quote
        $(Expr(:meta, :inline))
        Tuple{$(Ts...)}
    end
end

