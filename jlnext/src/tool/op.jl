#
# Scalar function lifted to a query combinator.
#

immutable OpTool <: AbstractTool
    op::Function
    itypes::Tuple{Vararg{Type}}
    otype::Type
    Fs::Vector{Tool}

    function OpTool(op::Function, itypes::Tuple{Vararg{Type}}, otype::Type, Fs::Vector{Tool})
        @assert method_exists(op, itypes)
        @assert length(itypes) == length(Fs)
        for (itype, F) in zip(itypes, Fs)
            @assert fits(domain(output(F)), Domain(itype))
        end
        return new(op, itypes, otype, Fs)
    end
end

immutable NullableOpTool <: AbstractTool
    op::Function
    itypes::Tuple{Vararg{Type}}
    otype::Type
    Fs::Vector{Tool}

    function NullableOpTool(op::Function, itypes::Tuple{Vararg{Type}}, otype::Type, Fs::Vector{Tool})
        @assert method_exists(op, itypes)
        @assert length(itypes) == length(Fs)
        for (itype, F) in zip(itypes, Fs)
            @assert fits(domain(output(F)), Domain(itype))
        end
        return new(op, itypes, otype, Fs)
    end
end

OpTool(op::Function, itypes, otype::Type, Fs) =
    OpTool(op, convert(Tuple{Vararg{Type}}, itypes), otype, convert(Vector{Tool}, Fs))

OpTool(op::Function, itypes, otype::Type, Fs::AbstractTool...) =
    OpTool(op, itypes, otype, collect(Tool, Fs))

OpTool(op::Function, otype, Fs::AbstractTool...) =
    let Fs = collect(Tool, Fs)
        OpTool(op, ((datatype(domain(output(F))) for F in Fs)...), otype, Fs)
    end

NullableOpTool(op::Function, itypes, otype::Type, Fs) =
    NullableOpTool(op, convert(Tuple{Vararg{Type}}, itypes), otype, convert(Vector{Tool}, Fs))

NullableOpTool(op::Function, itypes, otype::Type, Fs::AbstractTool...) =
    NullableOpTool(op, itypes, otype, collect(Tool, Fs))

NullableOpTool(op::Function, otype, Fs::AbstractTool...) =
    let Fs = collect(Tool, Fs)
        NullableOpTool(op, ((datatype(domain(output(F))) for F in Fs)...), otype, Fs)
    end

.==(F::AbstractTool, G::AbstractTool) = OpTool(==, Bool, F, G)
.!=(F::AbstractTool, G::AbstractTool) = OpTool(!=, Bool, F, G)
.<(F::AbstractTool, G::AbstractTool) = OpTool(<, Bool, F, G)
.<=(F::AbstractTool, G::AbstractTool) = OpTool(<=, Bool, F, G)
.>(F::AbstractTool, G::AbstractTool) = OpTool(>, Bool, F, G)
.>=(F::AbstractTool, G::AbstractTool) = OpTool(>=, Bool, F, G)

(~)(F::AbstractTool) = OpTool(!, (Bool,), Bool, Tool[F])
(&)(F::AbstractTool, G::AbstractTool) = OpTool(&, (Bool, Bool), Bool, Tool[F, G])
(|)(F::AbstractTool, G::AbstractTool) = OpTool(|, (Bool, Bool), Bool, Tool[F, G])

input(tool::OpTool) = ibound(Input, (input(F) for F in tool.Fs)...)
output(tool::OpTool) =
    Output(
        tool.otype,
        obound(OutputMode, (mode(output(F)) for F in tool.Fs)...))

input(tool::NullableOpTool) = ibound(Input, (input(F) for F in tool.Fs)...)
output(tool::NullableOpTool) =
    Output(
        tool.otype,
        obound(OutputMode, (mode(output(F)) for F in tool.Fs)...) |> setoptional())

run(tool::OpTool, iflow::InputFlow) =
    run(prim(tool), iflow)

run(tool::NullableOpTool, iflow::InputFlow) =
    run(prim(tool), iflow)

prim(tool::OpTool) =
    let omode = obound(OutputMode, (mode(output(F)) for F in tool.Fs)...)
        RecordTool(map(prim, tool.Fs)) >> OpPrimTool(tool.op, tool.itypes, tool.otype, omode)
    end

prim(tool::NullableOpTool) =
    let omode = obound(OutputMode, (mode(output(F)) for F in tool.Fs)...)
        RecordTool(map(prim, tool.Fs)) >>
        OpPrimTool(tool.op, tool.itypes, Nullable{tool.otype}, omode) >> NullablePrimTool(tool.otype)
    end

Op(op::Function, itypes::Tuple{Vararg{Type}}, otype::Type, Fs::Combinator...) =
    Combinator(
        P ->
            let Q = Start(P)
                P >> OpTool(op, itypes, otype, (F(Q) for F in Fs)...)
            end)

Op(op::Function, otype::Type, Fs::Combinator...) =
    Combinator(
        P ->
            let Q = Start(P)
                P >> OpTool(op, otype, (F(Q) for F in Fs)...)
            end)

NullableOp(op::Function, itypes::Tuple{Vararg{Type}}, otype::Type, Fs::Combinator...) =
    Combinator(
        P ->
            let Q = Start(P)
                P >> NullableOpTool(op, itypes, otype, (F(Q) for F in Fs)...)
            end)

NullableOp(op::Function, otype::Type, Fs::Combinator...) =
    Combinator(
        P ->
            let Q = Start(P)
                P >> NullableOpTool(op, otype, (F(Q) for F in Fs)...)
            end)

.==(F::Combinator, G::Combinator) = Op(==, Bool, F, G)
.!=(F::Combinator, G::Combinator) = Op(!=, Bool, F, G)
.<(F::Combinator, G::Combinator) = Op(<, Bool, F, G)
.<=(F::Combinator, G::Combinator) = Op(<=, Bool, F, G)
.>(F::Combinator, G::Combinator) = Op(>, Bool, F, G)
.>=(F::Combinator, G::Combinator) = Op(>=, Bool, F, G)

(~)(F::Combinator) = Op(!, (Bool,), Bool, F)
(&)(F::Combinator, G::Combinator) = Op(&, (Bool, Bool), Bool, F, G)
(|)(F::Combinator, G::Combinator) = Op(|, (Bool, Bool), Bool, F, G)

# Function primitive.

immutable OpPrimTool <: AbstractTool
    op::Function
    itypes::Tuple{Vararg{Type}}
    otype::Type
    mode::OutputMode
end

input(tool::OpPrimTool) =
    Input(((Output(itype, tool.mode) for itype in tool.itypes)...))
output(tool::OpPrimTool) =
    Output(tool.otype, tool.mode)

run_prim(tool::OpPrimTool, ds::DataSet) =
    isplain(tool.mode) ?
        run_plain_op(tool.op, tool.otype, length(ds), (values(flow) for flow in flows(ds))...) :
        run_op(tool.op, tool.otype, length(ds), (column(flow) for flow in flows(ds))...)

@generated function run_plain_op{T}(
        op::Function,
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
            vals[k] = op($((:($argvals_var[k]) for argvals_var in argvals_vars)...))
        end
        return Column(offs, vals)
    end
end

@generated function run_op{T}(
        op::Function,
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
        vals[n] = op($((val_vars[i] for i = 1:ar)...))
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

# Nullable to optional converter.

immutable NullablePrimTool <: AbstractTool
    otype::Type
end

input(tool::NullablePrimTool) = Input(Nullable{tool.otype})
output(tool::NullablePrimTool) = Output(tool.otype) |> setoptional()

function run_prim{T}(tool::NullablePrimTool, ivals::AbstractVector{Nullable{T}})
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

