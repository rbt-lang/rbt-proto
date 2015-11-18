
# Apply over a structure.
fmap{I,O}(pipe::AbstractPipe{I,O}, X::Iso{I}) =
    Iso{O}(apply(pipe, unwrap(X))::O)
fmap{I,O}(pipe::AbstractPipe{I,O}, X::Opt{I}) =
    !isnull(X) ? Opt{O}(apply(pipe, get(X))::O) : Opt{O}()
fmap{I,O}(pipe::AbstractPipe{I,O}, X::Seq{I}) =
    Seq{O}(O[apply(pipe, x)::O for x in X.vals])
fmap{I,O}(pipe::AbstractPipe{I,O}, X::Temp{I}) =
    Temp{O}(O[apply(pipe, x)::O for x in X.vals], X.idx)
fmap{Ns,Ps,I,O}(pipe::AbstractPipe{I,O}, X::Ctx{Ns,Ps,I}) =
    Ctx{Ns,Ps,O}(apply(pipe, X.val)::O, X.ctx)
fmap{Ns,Ps,I,O}(pipe::AbstractPipe{I,O}, X::CtxTemp{Ns,Ps,I}) =
    CtxTemp{Ns,Ps,O}(O[apply(pipe, x)::O for x in X.vals], X.idx, X.ctx)

# List of parameters (name => type or name => value).
params(::Type{Functor}) = ()
params(::Functor) = ()
params{Ns,Ps,T}(::Type{Ctx{Ns,Ps,T}}) =
    ([Pair(n, Ps.parameters[j]) for (j, n) in enumerate(Ns)]...)
params{Ns,Ps,T}(X::Ctx{Ns,Ps,T}) =
    ([Pair(n, X.ctx[j]) for (j, n) in enumerate(Ns)]...)
params{Ns,Ps,T}(::Type{CtxTemp{Ns,Ps,T}}) =
    ([Pair(n, Ps.parameters[j]) for (j, n) in enumerate(Ns)]...)
params{Ns,Ps,T}(X::CtxTemp{Ns,Ps,T}) =
    ([Pair(n, X.ctx[j]) for (j, n) in enumerate(Ns)]...)

# Change the element type.
functor(::Type{Iso}) = Iso
functor{T}(::Type{Iso{T}}) = Iso{T}
functor(::Type{Iso}, S) = Iso{S}
functor{T}(::Type{Iso{T}}, S) = Iso{S}
functor(::Type{Opt}) = Opt
functor{T}(::Type{Opt{T}}) = Opt{T}
functor(::Type{Opt}, S) = Opt{S}
functor{T}(::Type{Opt{T}}, S) = Opt{S}
functor(::Type{Seq}) = Seq
functor{T}(::Type{Seq{T}}) = Seq{T}
functor(::Type{Seq}, S) = Seq{S}
functor{T}(::Type{Seq{T}}, S) = Seq{S}
functor(::Type{Temp}) = Temp
functor{T}(::Type{Temp{T}}) = Temp{T}
functor(::Type{Temp}, S) = Temp{S}
functor{T}(::Type{Temp{T}}, S) = Temp{S}
functor{Ns,Ps}(::Type{Ctx{Ns,Ps}}) = Ctx{Ns,Ps}
functor{Ns,Ps,T}(::Type{Ctx{Ns,Ps,T}}) = Ctx{Ns,Ps,T}
functor{Ns,Ps}(::Type{Ctx{Ns,Ps}}, S) = Ctx{Ns,Ps,S}
functor{Ns,Ps,T}(::Type{Ctx{Ns,Ps,T}}, S) = Ctx{Ns,Ps,S}
functor{Ns,Ps}(::Type{CtxTemp{Ns,Ps}}) = CtxTemp{Ns,Ps}
functor{Ns,Ps,T}(::Type{CtxTemp{Ns,Ps,T}}) = CtxTemp{Ns,Ps,T}
functor{Ns,Ps}(::Type{CtxTemp{Ns,Ps}}, S) = CtxTemp{Ns,Ps,S}
functor{Ns,Ps,T}(::Type{CtxTemp{Ns,Ps,T}}, S) = CtxTemp{Ns,Ps,S}

# Lattices for input and output structures.
max{T}(X::Type{Iso{T}}) = X
max{T}(X::Type{Iso{T}}, ::Type{Iso{T}}) = X
max{T}(::Type{Iso{T}}, Y::Type{Opt{T}}) = Y
max{T}(::Type{Iso{T}}, Y::Type{Seq{T}}) = Y
max{T}(::Type{Iso{T}}, Y::Type{Temp{T}}) = Y
max{T}(::Type{Iso{T}}, Y::Type{SomeCtx{T}}) = Y
max{T}(::Type{Iso{T}}, Y::Type{SomeCtxTemp{T}}) = Y

max{T}(X::Type{Opt{T}}) = X
max{T}(X::Type{Opt{T}}, ::Type{Iso{T}}) = X
max{T}(X::Type{Opt{T}}, ::Type{Opt{T}}) = X
max{T}(::Type{Opt{T}}, Y::Type{Seq{T}}) = Y

max{T}(X::Type{Seq{T}}) = X
max{T}(X::Type{Seq{T}}, ::Type{Iso{T}}) = X
max{T}(X::Type{Seq{T}}, ::Type{Opt{T}}) = X
max{T}(X::Type{Seq{T}}, ::Type{Seq{T}}) = X

max{T}(X::Type{Temp{T}}) = X
max{T}(X::Type{Temp{T}}, ::Type{Iso{T}}) = X
max{T}(X::Type{Temp{T}}, ::Type{Temp{T}}) = X
max{Ns,Ps,T}(::Type{Temp{T}}, ::Type{Ctx{Ns,Ps,T}}) = CtxTemp{Ns,Ps,T}
max{T}(::Type{Temp{T}}, Y::Type{SomeCtxTemp{T}}) = Y

max{T}(X::Type{SomeCtx{T}}) = X
max{T}(X::Type{SomeCtx{T}}, ::Type{Iso{T}}) = X
max{Ns,Ps,T}(X::Type{Ctx{Ns,Ps,T}}, ::Type{Temp{T}}) = CtxTemp{Ns,Ps,T}
max{Ns1,Ps1,Ns2,Ps2,T}(X::Type{Ctx{Ns1,Ps1,T}}, Y::Type{Ctx{Ns2,Ps2,T}}) =
    if X == Y
        X
    else
        ps1 = Dict{Symbol,Type}(params(X))
        ps2 = Dict{Symbol,Type}(params(Y))
        Ns = (sort(unique([keys(ps1); keys(ps2)]))...)
        Ts = Type[]
        for n in Ns
            T1 = get(ps1, n, Any)
            T2 = get(ps2, n, Any)
            T = T1 == Any ? T2 :
                T2 == Any ? T1 :
                T1 == T2 ? T1 : Union{}
            push!(Ts, T)
        end
        Ps = Tuple{Ts...}
        Ctx{Ns,Ps,T}
    end
max{Ns1,Ps1,Ns2,Ps2,T}(X::Type{Ctx{Ns1,Ps1,T}}, Y::Type{CtxTemp{Ns2,Ps2,T}}) =
    let Z = max(X, Ctx{Ns2,Ps2,T})
        CtxTemp(Z.parameters...)
    end

max{T}(X::Type{SomeCtxTemp{T}}) = X
max{T}(X::Type{SomeCtxTemp{T}}, ::Type{Iso{T}}) = X
max{T}(X::Type{SomeCtxTemp{T}}, ::Type{Temp{T}}) = X
max{Ns1,Ps1,Ns2,Ps2,T}(::Type{CtxTemp{Ns1,Ps1,T}}, Y::Type{Ctx{Ns2,Ps2,T}}) =
    let Z = max(Ctx{Ns1,Ps1,T}, Y)
        CtxTemp(Z.parameters...)
    end
max{Ns1,Ps1,Ns2,Ps2,T}(::Type{CtxTemp{Ns1,Ps1,T}}, ::Type{CtxTemp{Ns2,Ps2,T}}) =
    let Z = max(Ctx{Ns1,Ps1,T}, Ctx{Ns2,Ps2,T})
        CtxTemp(Z.parameters...)
    end

# Converts from a plain Julia value.
wrap{T}(::Type{Iso{T}}, x::Iso{T}) = x
wrap{T}(::Type{Iso{T}}, x::T) = Iso{T}(x)
wrap{T}(::Type{Iso{T}}, x::Tuple{T, Dict{Symbol,Any}}) = Iso{T}(x)
wrap{T}(::Type{Opt{T}}, x::Opt{T}) = x
wrap{T}(::Type{Opt{T}}, x::Nullable{T}) = isnull(x) ? Opt{T}() : Opt{T}(get(x))
wrap{T}(::Type{Opt{T}}, x::T) = Opt{T}(Nullable{T}(x))
wrap{T}(::Type{Opt{T}}, ::Void) = Opt{T}(Nullable{T}())
wrap{T}(::Type{Seq{T}}, x::Seq{T}) = x
wrap{T}(::Type{Seq{T}}, x::Vector{T}) = Seq{T}(x)
wrap{T}(::Type{Seq{T}}, x::T) = Seq{T}(T[x])
wrap{T}(::Type{Seq{T}}, ::Void) = Seq{T}(T[])
wrap{T}(::Type{Temp{T}}, x::Temp{T}) = x
wrap{T}(::Type{Temp{T}}, x::T) = Temp{T}(T[x], 1)
wrap{T}(::Type{Temp{T}}, x::Tuple{T, Dict{Symbol,Any}}) = Temp{T}(T[x[1]], 1)
wrap{Ns,Ps,T}(::Type{Ctx{Ns,Ps,T}}, x::Ctx{Ns,Ps,T}) = x
wrap{Ns,Ps,T}(::Type{Ctx{Ns,Ps,T}}, x::Tuple{T, Dict{Symbol,Any}}) =
    let ps = x[2],
        ctx = convert(Ps, ([ps[n] for n in Ns]...))
        Ctx{Ns,Ps,T}(x[1], ctx)
    end
wrap{Ns,Ps,T}(::Type{CtxTemp{Ns,Ps,T}}, x::CtxTemp{Ns,Ps,T}) = x
wrap{Ns,Ps,T}(::Type{CtxTemp{Ns,Ps,T}}, x::Tuple{T, Dict{Symbol,Any}}) =
    let params = x[2],
        ctx = convert(Ps, ([params[n] for n in Ns]...))
        CtxTemp{Ns,Ps,T}(T[x[1]], 1, ctx)
    end
wrap(Fun, x, params::Dict{Symbol,Any}) =
    wrap(Fun, isempty(params) ? x : (x, params))

# Extracts a plain Julia value.
unwrap(X::Iso) = X.val
unwrap{T}(X::Opt{T}) = X.val0
unwrap(X::Seq) = X.vals
unwrap(X::Temp) = X.vals[X.idx]
unwrap(X::Ctx) = X.val
unwrap(x::CtxTemp) = X.vals[X.idx]
unwrap{T}(::Type{Iso{T}}) = T
unwrap{T}(::Type{Opt{T}}) = Nullable{T}
unwrap{T}(::Type{Seq{T}}) = Vector{T}
unwrap{T}(::Type{Temp{T}}) = T
unwrap{T}(::Type{SomeCtx{T}}) = T
unwrap{T}(::Type{SomeCtxTemp{T}}) = T

# Converts to a larger (output) or a smaller (input) structure.
rewrap{Fun<:Functor}(::Type{Fun}, X::Fun) = X

rewrap{T}(::Type{Opt{T}}, X::Iso{T}) = Opt{T}(unwrap(X))

rewrap{T}(::Type{Seq{T}}, X::Iso{T}) = Seq{T}(T[unwrap(X)])
rewrap{T}(::Type{Seq{T}}, X::Opt{T}) = Seq{T}(isnull(X) ? T[] : T[get(X)])

rewrap{T}(::Type{Iso{T}}, X::Union{Temp{T},SomeCtx{T},SomeCtxTemp{T}}) = Iso{T}(unwrap(X))

rewrap{T}(::Type{Temp{T}}, X::SomeCtxTemp{T}) = Temp{T}(X.vals, X.idx)

rewrap{Ns0,Ps0,Ns,Ps,T}(::Type{Ctx{Ns0,Ps0,T}}, X::Ctx{Ns,Ps,T}) =
    let ps = Dict{Symbol,Any}(params(X)),
        ctx = convert(Ps0, ([ps[n] for n in Ns0]...))
        Ctx{Ns0,Ps0,T}(X.val, ctx)
    end
rewrap{Ns0,Ps0,Ns,Ps,T}(::Type{Ctx{Ns0,Ps0,T}}, X::CtxTemp{Ns,Ps,T}) =
    let ps = Dict{Symbol,Any}(params(X)),
        ctx = convert(Ps0, ([ps[n] for n in Ns0]...))
        Ctx{Ns0,Ps0,T}(X.vals[X.idx], ctx)
    end
rewrap{Ns0,Ps0,Ns,Ps,T}(::Type{CtxTemp{Ns0,Ps0,T}}, X::CtxTemp{Ns,Ps,T}) =
    let ps = Dict{Symbol,Any}(params(X)),
        ctx = convert(Ps0, ([ps[n] for n in Ns0]...))
        CtxTemp{Ns0,Ps0,T}(X.vals, X.idx, ctx)
    end

# Duplicating the input structure.
dup{T}(X::Functor{T}) = dup(functor(typeof(X), typeof(X)), X)

dup{T}(::Type{Iso{Iso{T}}}, X::Iso{T}) = Iso{Iso{T}}(X)

dup{T}(::Type{Temp{Iso{T}}}, X::Temp{T}) =
    Temp{Iso{T}}(Iso{T}[Iso{T}(x) for x in X.vals], X.idx)
dup{T}(::Type{Temp{Temp{T}}}, X::Temp{T}) =
    Temp{Temp{T}}(Temp{T}[Temp{T}(X.vars, j) for j = 1:length(X.vars)], X.idx)

dup{Ns,Ps,T}(::Type{Ctx{Ns,Ps,Iso{T}}}, X::Ctx{Ns,Ps,T}) =
    Ctx{Ns,Ps,Iso{T}}(Iso{X.val}, X.ctx)
dup{Ns,Ps,T}(::Type{Ctx{Ns,Ps,Ctx{Ns,Ps,T}}}, X::Ctx{Ns,Ps,T}) =
    Ctx{Ns,Ps,Ctx{Ns,Ps,T}}(X, X.ctx)
dup{Ns0,Ps0,Ns,Ps,T}(::Type{Ctx{Ns,Ps,Ctx{Ns0,Ps0,T}}}, X::Ctx{Ns,Ps,T}) =
    let ps = Dict{Symbol,Any}(params(X)),
        ctx = convert(Ps0, ([ps[n] for n in Ns0]...))
        Ctx{Ns,Ps,Ctx{Ns0,Ps0,T}}(Ctx{Ns0,Ps0,T}(X.val, ctx), X.ctx)
    end

dup{Ns,Ps,T}(::Type{CtxTemp{Ns,Ps,Iso{T}}}, X::CtxTemp{Ns,Ps,T}) =
    CtxTemp{Ns,Ps,Iso{T}}(Iso{T}[Iso{T}(x) for x in X.vals], X.idx, X.ctx)
dup{Ns,Ps,T}(::Type{CtxTemp{Ns,Ps,Temp{T}}}, X::CtxTemp{Ns,Ps,T}) =
    CtxTemp{Ns,Ps,Temp{T}}(Temp{T}[Temp{T}(X.vars, j) for j = 1:length(X.vars)], X.idx, X.ctx)
dup{Ns,Ps,T}(::Type{CtxTemp{Ns,Ps,Ctx{Ns,Ps,T}}}, X::CtxTemp{Ns,Ps,T}) =
    let TT = Ctx{Ns,Ps,T}
        CtxTemp{Ns,Ps,TT}(TT[TT(x, X.ctx) for x in X.vals], X.idx, X.ctx)
    end
dup{Ns0,Ps0,Ns,Ps,T}(::Type{CtxTemp{Ns,Ps,Ctx{Ns0,Ps0,T}}}, X::CtxTemp{Ns,Ps,T}) =
    let TT = Ctx{Ns0,Ps0,T},
        ps = Dict{Symbol,Any}(params(X)),
        ctx = convert(Ps0, ([ps[n] for n in Ns0]...))
        CtxTemp{Ns,Ps,TT}(TT[TT(x, ctx) for x in X.vals], X.idx, X.ctx)
    end
dup{Ns,Ps,T}(::Type{CtxTemp{Ns,Ps,CtxTemp{Ns,Ps,T}}}, X::CtxTemp{Ns,Ps,T}) =
    let TT = CtxTemp{Ns,Ps,T}
        CtxTemp{Ns,Ps,TT}(TT[TT(X.vars, j, X.ctx) for j = 1:length(X.vars)], X.idx, X.ctx)
    end
dup{Ns0,Ps0,Ns,Ps,T}(::Type{CtxTemp{Ns,Ps,CtxTemp{Ns0,Ps0,T}}}, X::CtxTemp{Ns,Ps,T}) =
    let TT = CtxTemp{Ns0,Ps0,T},
        ps = Dict{Symbol,Any}(params(X)),
        ctx = convert(Ps0, ([ps[n] for n in Ns0]...))
        CtxTemp{Ns,Ps,TT}(TT[TT(X.vars, j, ctx) for j = 1:length(X.vars)], X.idx, X.ctx)
    end

# Flattening output.
flat{T}(X::Iso{Iso{T}}) = unwrap(X)
flat{T}(X::Iso{Opt{T}}) = unwrap(X)
flat{T}(X::Iso{Seq{T}}) = unwrap(X)

flat{T}(X::Opt{Iso{T}}) = isnull(X) ? Opt{T}() : Opt{T}(unwrap(get(X)))
flat{T}(X::Opt{Opt{T}}) = isnull(X) || isnull(get(X)) ? Opt{T}() : Opt{T}(get(get(X)))
flat{T}(X::Opt{Seq{T}}) = get(X, Seq{T}(T[]))

flat{T}(X::Seq{Iso{T}}) = Seq{T}(T[unwrap(x) for x in X])
flat{T}(X::Seq{Opt{T}}) =
    let ys = T[]
        for Y in X
            if !isnull(Y)
                push!(ys, get(Y))
            end
        end
        Seq{T}(ys)
    end
flat{T}(X::Seq{Seq{T}}) =
    let ys = T[]
        for Y in X
            append!(ys, unwrap(Y))
        end
        Seq{T}(ys)
    end

# Distributing output over input.
dist{T}(X::Iso{Iso{T}}) = X
dist{T}(X::Iso{Opt{T}}) =
    let Y = unwrap(X)
        isnull(Y) ? Opt{Iso{T}}() : Opt{Iso{T}}(Iso{T}(get(Y)))
    end
dist{T}(X::Iso{Seq{T}}) =
    Seq{Iso{T}}(Iso{T}[Iso{T}(y) for y in unwrap(X)])

dist{T}(X::Temp{Iso{T}}) =
    Iso{Temp{T}}(Temp{T}(T[unwrap(x) for x in X.vals], X.idx))
dist{T}(X::Temp{Opt{T}}) =
    let Y = unwrap(X)
        if isnull(Y)
            Opt{Temp{T}}()
        else
            let vals = T[],
                idx = 0
                for j = 1:length(X.vals)
                    if !isnull(X.vals[j])
                        push!(vals, get(X.vals[j]))
                        if j == X.idx
                            idx = endof(vals)
                        end
                    end
                end
            end
            Opt{Temp{T}}(Temp{T}(vals, idx))
        end
    end
dist{T}(X::Temp{Seq{T}}) =
    let Y = unwrap(X)
        if isempty(Y)
            Seq{Temp{T}}(Temp{T}[])
        else
            let vals = T[],
                idx1 = 0,
                idx2 = 0
                for j = 1:length(X.vals)
                    if j == X.idx
                        idx1 = endof(vals)+1
                    end
                    append!(vals, unwrap(X.vals[j]))
                    if j == X.idx
                        idx2 = endof(vals)
                    end
                end
            end
            Seq{Temp{T}}(Temp{T}[Temp{T}(vals, idx) for idx = idx1:idx2])
        end
    end

dist{Ns,Ps,T}(X::Ctx{Ns,Ps,Iso{T}}) = Iso{Ctx{Ns,Ps,T}}(Ctx{Ns,Ps,T}(X.val.val, X.ctx))
dist{Ns,Ps,T}(X::Ctx{Ns,Ps,Opt{T}}) =
    let Y = unwrap(X)
        isnull(Y) ? Opt{Ctx{Ns,Ps,T}}() : Ops{Ctx{Ns,Ps,T}}(Ctx{Ns,Ps,T}(get(Y), X.ctx))
    end
dist{Ns,Ps,T}(X::Ctx{Ns,Ps,Seq{T}}) =
    Seq{Ctx{Ns,Ps,T}}(Ctx{Ns,Ps,T}[Ctx{Ns,Ps,T}(y, X.ctx) for y in unwrap(X)])

dist{Ns,Ps,T}(X::CtxTemp{Ns,Ps,Iso{T}}) =
    Iso{CtxTemp{Ns,Ps,T}}(CtxTemp{Ns,Ps,T}(T[unwrap(x) for x in X.vals], X.idx, X.ctx))
dist{Ns,Ps,T}(X::CtxTemp{Ns,Ps,Opt{T}}) =
    let Y = unwrap(X)
        if isnull(Y)
            Opt{CtxTemp{Ns,Ps,T}}()
        else
            let vals = T[],
                idx = 0
                for j = 1:length(X.vals)
                    if !isnull(X.vals[j])
                        push!(vals, get(X.vals[j]))
                        if j == X.idx
                            idx = endof(vals)
                        end
                    end
                end
            end
            Opt{CtxTemp{Ns,Ps,T}}(CtxTemp{Ns,Ps,T}(vals, idx, X.ctx))
        end
    end
dist{Ns,Ps,T}(X::CtxTemp{Ns,Ps,Seq{T}}) =
    let Y = unwrap(X)
        if isempty(Y)
            Seq{CtxTemp{Ns,Ps,T}}(CtxTemp{Ns,Ps,T}[])
        else
            let vals = T[],
                idx1 = 0,
                idx2 = 0
                for j = 1:length(X.vals)
                    if j == X.idx
                        idx1 = endof(vals)+1
                    end
                    append!(vals, unwrap(X.vals[j]))
                    if j == X.idx
                        idx2 = endof(vals)
                    end
                end
            end
            Seq{CtxTemp{Ns,Ps,T}}(CtxTemp{Ns,Ps,T}[CtxTemp{Ns,Ps,T}(vals, idx, X.ctx) for idx = idx1:idx2])
        end
    end

# Iterators.
start{T}(X::Functor{T}) = true
next{T}(X::Functor{T}, state) = (unwrap(X)::T, false)
done{T}(X::Functor{T}, state) = state

start(X::Opt) = !X.isnull
next(X::Opt, state) = (X.val, false)
done(X::Opt, state) = state

start(X::Seq) = start(X.vals)
next(X::Seq, state) = next(X.vals, state)
done(X::Seq, state) = done(X.vals, state)

