#
# Scalar function lifted to a query combinator.
#

function LiftQuery(fn, argtypes::Tuple{Vararg{Type}}, restype::Type, qs::Vector{Query})
    @assert method_exists(fn, argtypes) "$fn($(join(argtypes, ", "))) is not defined"
    @assert length(argtypes) == length(qs)
    qs′ = Query[]
    for (argtype, q) in zip(argtypes, qs)
        if argtype <: Nullable
            T = eltype(argtype)
            if fits(output(q), Output(T) |> setoptional())
                q = RecordQuery(q)
                q = q >> Query(EncodeNullableSig(), Input(domain(output(q))), Output(Nullable{T}))
            end
        elseif argtype <: Vector
            T = eltype(argtype)
            if fits(output(q), Output(T) |> setoptional() |> setplural())
                q = RecordQuery(q)
                q = q >> Query(EncodeVectorSig(), Input(domain(output(q))), Output(Vector{T}))
            end
        end
        @assert fits(domain(output(q)), Domain(argtype)) "$q does not fit $argtype"
        push!(qs′, q)
    end
    argq = RecordQuery(qs′)
    sig = LiftSig(fn, argtypes, restype)
    ity = Input(domain(output(argq)))
    oty = Output(restype, obound([mode(output(q)) for q in qs′]))
    return argq >> Query(sig, ity, oty)
end

LiftQuery{T}(fn, argtypes::Tuple{Vararg{Type}}, restype::Type{Nullable{T}}, qs::Vector{Query}) =
    let q = invoke(LiftQuery, (Any, Tuple{Vararg{Type}}, Type, Vector{Query}), fn, argtypes, restype, qs)
        q >> Query(DecodeNullableSig(), Input(Nullable{T}), Output(T) |> setoptional())
    end

LiftQuery{T}(fn, argtypes::Tuple{Vararg{Type}}, restype::Type{Vector{T}}, qs::Vector{Query}) =
    let q = invoke(LiftQuery, (Any, Tuple{Vararg{Type}}, Type, Vector{Query}), fn, argtypes, restype, qs)
        q >> Query(DecodeVectorSig(), Input(Vector{T}), Output(T) |> setoptional() |> setplural())
    end

LiftQuery(fn, argtypes::Tuple{Vararg{Type}}, restype::Type, qs::Query...) =
    LiftQuery(fn, argtypes, restype, collect(qs))

LiftQuery(fn, argtypes::Tuple{Vararg{Type}}, qs::Vector{Query}) =
    let restype = Union{Base.return_types(fn, argtypes)...}
        LiftQuery(fn, argtypes, restype, qs)
    end

LiftQuery(fn, argtypes::Tuple{Vararg{Type}}, qs::Query...) =
    LiftQuery(fn, argtypes, collect(qs))

LiftQuery(fn, qs::Vector{Query}) =
    let argtypes = ((datatype(domain(output(q))) for q in qs)...)
        LiftQuery(fn, argtypes, qs)
    end

LiftQuery(fn, qs::Query...) =
    LiftQuery(fn, collect(qs))

immutable LiftSig <: AbstractPrimitive
    fn::Function
    argtypes::Tuple{Vararg{Type}}
    restype::Type
end

describe(io::IO, sig::LiftSig) = print(io, sig.fn, "′")

ev(sig::LiftSig, dv::DataVector) =
    all(isplain, columns(dv)) ?
        plain_lift_impl(sig.fn, sig.restype, length(dv), map(values, columns(dv))...) :
        lift_impl(sig.fn, sig.restype, length(dv), columns(dv)...)

@generated function plain_lift_impl{T}(
        fn::Function,
        otype::Type{T},
        len::Int,
        args::AbstractVector...)
    ar = length(args)
    argvals_vars = ((Symbol("argvals", i) for i = 1:ar)...)
    init = :()
    for i = 1:ar
        init = quote
            $init
            $(argvals_vars[i]) = args[$i]
        end
    end
    return quote
        $init
        ($(argvals_vars...),) = args
        vals = Vector{T}(len)
        @inbounds for k = 1:len
            vals[k] = fn($((:($argvals_var[k]) for argvals_var in argvals_vars)...))
        end
        return PlainColumn(vals)
    end
end

@generated function lift_impl{T}(
        fn::Function,
        otype::Type{T},
        len::Int,
        args::Column...)
    optional = any(isoptional, args)
    plural = any(isplural, args)
    ar = length(args)
    argoffs_vars = ((Symbol("argoffs", i) for i = 1:ar)...)
    argvals_vars = ((Symbol("argvars", i) for i = 1:ar)...)
    idx_vars = ((Symbol("idx", i) for i = 1:ar)...)
    val_vars = ((Symbol("val", i) for i = 1:ar)...)
    init = :()
    for i = 1:ar
        init = quote
            $init
            $(argoffs_vars[i]) = offsets(args[$i])
            $(argvals_vars[i]) = values(args[$i])
        end
    end
    loop = quote
        vals[n] = fn($((val_vars[i] for i = 1:ar)...))
        n += 1
    end
    for i = ar:-1:1
        loop = quote
            for $(idx_vars[i]) = $(argoffs_vars[i])[k]:$(argoffs_vars[i])[k+1]-1
                $(val_vars[i]) = $(argvals_vars[i])[$(idx_vars[i])]
                $loop
            end
        end
    end
    return quote
        $init
        size = 0
        for k = 1:len
            size += *(1, $((:($(argoffs_vars[i])[k+1]-$(argoffs_vars[i])[k]) for i = 1:ar)...))
        end
        offs = Vector{Int}(len+1)
        vals = Vector{T}(size)
        offs[1] = 1
        if size == 0
            for k = 1:len
                offs[k+1] = 1
            end
            return Column{$optional,$plural}(offs, vals)
        end
        n = 1
        for k = 1:len
            $loop
            offs[k+1] = n
        end
        return Column{$optional,$plural}(offs, vals)
    end
end

# Nullable to optional decoder.

immutable DecodeNullableSig <: AbstractPrimitive
end

function ev{T}(::DecodeNullableSig, ivals::AbstractVector{Nullable{T}})
    len = length(ivals)
    sz = 0
    for val in ivals
        if !isnull(val)
            sz += 1
        end
    end
    offs = Vector{Int}(len+1)
    vals = Vector{T}(sz)
    offs[1] = 1
    n = 1
    for k = 1:len
        val = ivals[k]
        if !isnull(val)
            vals[n] = get(val)
            n += 1
        end
        offs[k+1] = n
    end
    return OptionalColumn(offs, vals)
end

# Vector to plural decoder.

immutable DecodeVectorSig <: AbstractPrimitive
end

function ev{T}(::DecodeVectorSig, ivals::AbstractVector{Vector{T}})
    len = length(ivals)
    sz = 0
    for val in ivals
        sz += length(val)
    end
    offs = Vector{Int}(len+1)
    vals = Vector{T}(sz)
    offs[1] = 1
    n = 1
    for k = 1:len
        for val in ivals[k]
            vals[n] = val
            n += 1
        end
        offs[k+1] = n
    end
    return PluralColumn(offs, vals)
end

function ev{V<:AbstractVector}(::DecodeVectorSig, ivals::AbstractVector{V})
    len = length(ivals)
    sz = 0
    for val in ivals
        sz += length(val)
    end
    offs = Vector{Int}(len+1)
    vals = Vector{eltype(V)}(sz)
    offs[1] = 1
    n = 1
    for k = 1:len
        for val in ivals[k]
            vals[n] = val
            n += 1
        end
        offs[k+1] = n
    end
    return PluralColumn(offs, vals)
end

# Optional to Nullable encoder.

immutable EncodeNullableSig <: AbstractPrimitive
end

function ev(::EncodeNullableSig, dv::DataVector)
    return encode_nullable_impl(column(dv, 1))
end

function encode_nullable_impl(col::Column)
    cr = cursor(col)
    T = eltype(col.vals)
    vals = Vector{Nullable{T}}(length(col))
    while !done(col, cr)
        next!(col, cr)
        vals[cr.pos] = length(cr) > 0 ? Nullable{T}(cr[1]) : Nullable{T}()
    end
    return PlainColumn(vals)
end

# Plural to Vector encoder.

immutable EncodeVectorSig <: AbstractPrimitive
end

function ev(::EncodeVectorSig, dv::DataVector)
    return encode_vector_impl(column(dv, 1))
end

function encode_vector_impl(col::Column)
    cr = cursor(col)
    T = eltype(col.vals)
    vals = Vector{Vector{T}}(length(col))
    while !done(col, cr)
        next!(col, cr)
        vals[cr.pos] = cr[1:end]
    end
    return PlainColumn(vals)
end

