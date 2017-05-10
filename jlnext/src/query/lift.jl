#
# Scalar function lifted to a query combinator.
#

function LiftQuery(fn, argtypes::Tuple{Vararg{Type}}, restype::Type, qs::Vector{Query})
    @assert method_exists(fn, argtypes) "$fn($(join(argtypes, ", "))) is not defined"
    @assert length(argtypes) == length(qs)
    for (argtype, q) in zip(argtypes, qs)
        @assert fits(domain(output(q)), Domain(argtype))
    end
    argq = RecordQuery(qs)
    sig = LiftSig(fn, argtypes, restype)
    ity = Input(domain(output(argq)))
    oty = Output(restype, obound([mode(output(q)) for q in qs]))
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

ev(sig::LiftSig, ds::DataSet) =
    all(isplain(output(flow)) for flow in flows(ds)) ?
        ev_plain_fn(sig.fn, sig.restype, length(ds), (values(flow) for flow in flows(ds))...) :
        ev_fn(sig.fn, sig.restype, length(ds), (column(flow) for flow in flows(ds))...)

@generated function ev_plain_fn{T}(
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
        offs = OneTo(len+1)
        vals = Vector{T}(len)
        for k = 1:len
            vals[k] = fn($((:($argvals_var[k]) for argvals_var in argvals_vars)...))
        end
        return Column(offs, vals)
    end
end

@generated function ev_fn{T}(
        fn::Function,
        otype::Type{T},
        len::Int,
        args::Column...)
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
            return Column(offs, vals)
        end
        n = 1
        for k = 1:len
            $loop
            offs[k+1] = n
        end
        return Column(offs, vals)
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
    return Column(offs, vals)
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
    return Column(offs, vals)
end

