#
# Runtime representation of input and output values.
#


#
# Structured input or output type.
#

abstract Kind{T}

eltype{T}(::Type{Kind{T}}) = T

# Internal representation of the structure.
data(X::Kind) = X.data


#
# Structure-free input or output.
#

immutable Iso{T} <: Kind{T}
    data::T

    Iso(val::T) = new(val)
end

Iso{T}(val::T) = Iso{T}(val)

data{T}(::Type{Iso{T}}) = T

Kind{K<:Iso}(::Type{K}, T::Type) = Iso{T}

start(X::Iso) = true
next(X::Iso, state) = (data(X), false)
done(X::Iso, state) = state


#
# Partial output.
#

typealias OptData{T} Nullable{T}

immutable Opt{T} <: Kind{T}
    data::OptData{T}

    Opt(data::OptData{T}) = new(data)
    Opt(val::T) = new(Nullable{T}(val))
    Opt() = new(OptData{T}())
end

Opt{T}(val::T) = Opt{T}(Nullable{T}(val))
Opt() = Opt{Union{}}(Nullable())

isnull(X::Opt) = isnull(X.data)
get(X::Opt) = get(X.data)
get(X::Opt, default) = get(X.data, default)

data{T}(::Type{Opt{T}}) = OptData{T}

Kind{K<:Opt}(::Type{K}, T::Type) = Opt{T}

start(X::Opt) = !isnull(X)
next(X::Opt, state) = (get(X), false)
done(X::Opt, state) = state


#
# Plural output.
#

typealias SeqData{T} Vector{T}

immutable Seq{T} <: Kind{T}
    data::SeqData{T}

    Seq(data::SeqData{T}) = new(data)
    Seq() = new(T[])
end

Seq{T}(vals::AbstractVector{T}) = Seq{T}(vals)

length(X::Seq) = length(X.data)
isempty(X::Seq) = isempty(X.data)
endof(X::Seq) = endof(X.data)
eachindex(X::Seq) = eachindex(X.data)
getindex(X::Seq, keys...) = getindex(X.data, keys...)

data{T}(::Type{Seq{T}}) = SeqData{T}

Kind{K<:Seq}(::Type{K}, T::Type) = Seq{T}

start(X::Seq) = start(data(X))
next(X::Seq, state) = next(data(X), state)
done(X::Seq, state) = done(data(X), state)


#
# Input with surrounding context (that is, preceeding and subsequent values).
#

typealias RelData{T} Pair{Int,Vector{T}}

immutable Rel{T} <: Kind{T}
    data::RelData{T}

    Rel(data::RelData{T}) = new(data)
    Rel(ptr::Int, vals::Vector{T}) = new(RelData{T}(ptr, vals))
end

Rel{T}(ptr::Int, vals::Vector{T}) = Rel{T}(RelData(ptr, vals))

data{T}(::Type{Rel{T}}) = RelData{T}

Kind{K<:Rel}(::Type{K}, T::Type) = Rel{T}


#
# Input with named parameters.
#

# Ns is Val{(:x, :y, :z, ...)}, Vs is Tuple{Int, Int, Float64, ...}.
typealias EnvData{Ns,Vs,T} Pair{Vs,T}

immutable Env{Ns,Vs,T} <: Kind{T}
    data::EnvData{Ns,Vs,T}

    Env(data::EnvData{Ns,Vs,T}) = new(data)
    Env(env::Vs, val::T) = new(EnvData{Ns,Vs,T}(env, val))
end

Env{Ns<:Val,Vs<:Tuple,T}(::Type{Ns}, env::Vs, val::T) =
    Env{Ns,Vs,T}(EnvData(env, val))

data{Ns,Vs,T}(::Type{Env{Ns,Vs,T}}) = EnvData{Ns,Vs,T}

envsig{Ns,Vs,T}(::Type{Env{Ns,Vs,T}}) = Ns
envsig{Ns,Vs,T}(::Env{Ns,Vs,T}) = Ns
envtype{Ns,Vs,T}(::Type{Env{Ns,Vs,T}}) = Vs
envtype{Ns,Vs,T}(::Env{Ns,Vs,T}) = Vs

Kind{K<:Env}(::Type{K}, T::Type) = Env{envsig(K), envtype(K), T}


#
# Input with both named parameters and surrounding context.
#

typealias EnvRelData{Ns,Vs,T} EnvData{Ns,Vs,RelData{T}}

immutable EnvRel{Ns,Vs,T} <: Kind{T}
    data::EnvRelData{Ns,Vs,T}

    EnvRel(data::EnvRelData{Ns,Vs,T}) = new(data)
    EnvRel(env::Vs, ptr::Int, vals::Vector{T}) =
        new(EnvRelData{Ns,Vs,T}(env, RelData{T}(ptr, vals)))
end

EnvRel{Ns<:Val,Vs<:Tuple,T}(::Type{Ns}, env::Vs, ptr::Int, vals::Vector{T}) =
    EnvRel{Ns,Vs,T}(EnvData(env, RelData(ptr, vals)))

data{Ns,Vs,T}(::Type{EnvRel{Ns,Vs,T}}) = EnvRelData{Ns,Vs,T}

envsig{Ns,Vs,T}(::Type{EnvRel{Ns,Vs,T}}) = Ns
envsig{Ns,Vs,T}(::EnvRel{Ns,Vs,T}) = Ns
envtype{Ns,Vs,T}(::Type{EnvRel{Ns,Vs,T}}) = Vs
envtype{Ns,Vs,T}(::EnvRel{Ns,Vs,T}) = Vs

Kind{K<:EnvRel}(::Type{K}, T::Type) = EnvRel{envsig(K), envtype{K}, T}


#
# Wrapping plain Julia values.
#

# Output.

convert{T}(K::Type{Iso{T}}, X::Iso{T}) = X
convert{T}(K::Type{Iso{T}}, val) =
    K(convert(T, val))

convert{T}(K::Type{Opt{T}}, X::Opt{T}) = X
convert{T}(K::Type{Opt{T}}, val) =
    K(convert(Nullable{T}, val))
convert{T}(K::Type{Opt{T}}) =
    K(Nullable{T}())

convert{T}(K::Type{Seq{T}}, X::Seq{T}) = X
convert{T}(K::Type{Seq{T}}, vals) =
    K(convert(Vector{T}, vals))

# Input.

convert{T}(K::Type{Iso{T}}) =
    K(nothing)

convert{T}(K::Type{Rel{T}}, X::Rel{T}) = X
convert{T}(K::Type{Rel{T}}, data::RelData{T}) =
    K(data)
convert{T}(K::Type{Rel{T}}, ptr::Int, vals) =
    K(RelData{T}(ptr, vals))
convert{T}(K::Type{Rel{T}}, val) =
    K(RelData{T}(1, T[val]))
convert{T}(K::Type{Rel{T}}) =
    K(RelData{T}(1, T[nothing]))

convert{Ns,Vs,T}(K::Type{Env{Ns,Vs,T}}, X::Env{Ns,Vs,T}) = X
convert{Ns,Vs,T}(K::Type{Env{Ns,Vs,T}}, data::EnvData{Ns,Vs,T}) =
    K(data)
convert{Ns,Vs,T}(K::Type{Env{Ns,Vs,T}}, env::Vs, val=nothing) =
    K(EnvData{Ns,Vs,T}(env, val))
convert{Ns,Vs,T}(K::Type{Env{Ns,Vs,T}}, params::Dict{Symbol,Any}=Dict{Symbol,Any}(), val=nothing) =
    let env = convertparams(Ns, Vs, params)
        K(env, val)
    end
convert{Ns,Vs,T}(K::Type{Env{Ns,Vs,T}}, args...; params...) =
    K(Dict{Symbol,Any}(params), args...)

convert{Ns,Vs,T}(K::Type{EnvRel{Ns,Vs,T}}, X::EnvRel{Ns,Vs,T}) = X
convert{Ns,Vs,T}(K::Type{EnvRel{Ns,Vs,T}}, data::EnvRelData{Ns,Vs,T}) =
    K(data)
convert{Ns,Vs,T}(K::Type{EnvRel{Ns,Vs,T}}, env::Vs, ptr::Int, vals) =
    K(EnvRelData{Ns,Vs,T}(env, RelData{T}(ptr, vals)))
convert{Ns,Vs,T}(K::Type{EnvRel{Ns,Vs,T}}, env::Vs, val=nothing) =
    K(env, 1, T[val])
convert{Ns,Vs,T}(K::Type{EnvRel{Ns,Vs,T}}, params::Dict{Symbol,Any}, ptr::Int, vals) =
    let env = convertparams(Ns,Vs, params)
        K(env, ptr, vals)
    end
convert{Ns,Vs,T}(K::Type{EnvRel{Ns,Vs,T}}, ptr::Int, vals) =
    K(Dict{Symbol,Any}(), ptr, vals)
convert{Ns,Vs,T}(K::Type{EnvRel{Ns,Vs,T}}, params::Dict{Symbol,Any}=Dict{Symbol,Any}(), val=nothing) =
    K(params, 1, T[val])
convert{Ns,Vs,T}(K::Type{EnvRel{Ns,Vs,T}}, args...; params...) =
    K(Dict{Symbol,Any}(params), args...)

convertparams{names,Vs<:Tuple}(::Type{Val{names}}, ::Type{Vs}, params::Dict{Symbol,Any}) =
        ntuple(n -> convert(Vs.parameters[n], get(params, names[n], nothing)), length(names))


#
# Getting the value out of the input structure.
#

get(X::Iso) = data(X)

get(X::Rel) =
    begin
        ptr, vals = data(X)
        return vals[ptr]
    end

get(X::Env) =
    begin
        env, val = data(X)
        return val
    end

get(X::EnvRel) =
    begin
        env, (ptr, vals) = data(X)
        return vals[ptr]
    end


#
# Converting an input/output structure to a smaller/larger structure.
#

lift{K<:Kind}(::Type{K}, X::K) = X

# Output.

lift{T}(K::Type{Iso{T}}, X::Iso) = K(data(X))

lift{T}(K::Type{Opt{T}}, X::Iso) = K(Nullable{T}(data(X)))
lift{T}(K::Type{Opt{T}}, X::Opt) = K(Nullable{T}(data(X)))

lift{T}(K::Type{Seq{T}}, X::Iso) = K(T[data(X)])
lift{T}(K::Type{Seq{T}}, X::Opt) = K(isnull(X) ? T[] : T[get(X)])
lift{T}(K::Type{Seq{T}}, X::Seq) = K(Vector{T}(data(X)))

# Input.

lift{K<:Iso}(::Type{K}, X::Rel) =
    begin
        ptr, vals = data(X)
        return K(vals[ptr])
    end
lift{K<:Iso}(::Type{K}, X::Env) =
    begin
        env, val = data(X)
        return K(val)
    end
lift{K<:Iso}(::Type{K}, X::EnvRel) =
    begin
        env, (ptr, vals) = data(X)
        return K(vals[ptr])
    end

lift{K<:Rel}(::Type{K}, X::Rel) =
    begin
        ptr, vals = data(X)
        return K(ptr, vals)
    end
lift{K<:Rel}(::Type{K}, X::EnvRel) =
    begin
        env, (ptr, vals) = data(X)
        return K(ptr, vals)
    end

lift{K<:Env}(::Type{K}, X::Env) =
    begin
        Ns, Vs = envsig(K), envtype(K)
        Ns0, Vs0 = envsig(X), envtype(X)
        env, val = data(X)
        return K(liftenv(Ns, Vs, Ns0, Vs0, env), val)
    end
lift{K<:Env}(::Type{K}, X::EnvRel) =
    begin
        Ns, Vs = envsig(K), envtype(K)
        Ns0, Vs0 = envsig(X), envtype(X)
        env, (ptr, vals) = data(X)
        return K(liftenv(Ns, Vs, Ns0, Vs0, env), vals[ptr])
    end

lift{K<:EnvRel}(::Type{K}, X::EnvRel) =
    begin
        Ns, Vs = envsig(K), envtype(K)
        Ns0, Vs0 = envsig(X), envtype(X)
        env, (ptr, vals) = data(X)
        return K(liftenv(Ns, Vs, Ns0, Vs0, env), ptr, vals)
    end

@generated function liftenv{names,Vs,names0,Vs0}(
    ::Type{Val{names}}, ::Type{Vs}, ::Type{Val{names0}}, ::Type{Vs0}, env::Vs0)
    if names == names0 && Vs == Vs0
        return :(env)
    else
        items = []
        indexes = Dict{Symbol,Int}([name => n for (n, name) in enumerate(names0)])
        for (name, V) in zip(names, Vs.parameters)
            index = indexes[name]
            push!(items, :(env[$index]))
        end
        return :(convert(Vs, $(Expr(:tuple, items...))))
    end
end


#
# Duplicate input: W{T} -> W_2{W_1{T}}.
#

dup{K<:Kind,K0<:Kind}(KK::Type{Iso{K}}, X::K0) = KK(lift(K, X))

dup{K<:Kind,K0<:Rel}(KK::Type{Rel{K}}, X::K0) =
    begin
        ptr, vals = data(X)
        KK(ptr, K[lift(K, K0(n, vals)) for n = 1:length(vals)])
    end
dup{K<:Kind,K0<:EnvRel}(KK::Type{Rel{K}}, X::K0) =
    begin
        env, (ptr, vals) = data(X)
        KK(ptr, K[lift(K, K0(env, n, vals)) for n = 1:length(vals)])
    end

dup{Ns,Vs,K<:Kind,K0<:Env}(KK::Type{Env{Ns,Vs,K}}, X::K0) =
    begin
        Ns0, Vs0 = envsig(K0), envtype(K0)
        env, val = data(X)
        return KK(liftenv(Ns, Vs, Ns0, Vs0, env), lift(K, X))
    end
dup{Ns,Vs,K<:Kind,K0<:EnvRel}(KK::Type{Env{Ns,Vs,K}}, X::K0) =
    begin
        Ns0, Vs0 = envsig(K0), envtype(K0)
        env, (ptr, vals) = data(X)
        return KK(liftenv(Ns, Vs, Ns0, Vs0, env), lift(K, X))
    end

dup{Ns,Vs,K<:Kind,K0<:EnvRel}(KK::Type{EnvRel{Ns,Vs,K}}, X::K0) =
    begin
        Ns0, Vs0 = envsig(K0), envtype(K0)
        env, (ptr, vals) = data(X)
        return KK(
            liftenv(Ns, Vs, Ns0, Vs0, env),
            ptr,
            K[lift(K, K0(env, n, vals)) for n = 1:length(vals)])
    end


#
# Distributive law: W_2{M_1{T}} -> M_1{W_2{T}}.
#

dist{T}(XX::Iso{Iso{T}}) = XX
dist{T}(XX::Iso{Opt{T}}) =
    let K = Iso{T},
        X = data(XX)
        isnull(X) ? Opt{K}() : Opt{K}(K(get(X)))
    end
dist{T}(XX::Iso{Seq{T}}) =
    let K = Iso{T}
        Seq{K}(K[K(x) for x in data(XX)])
    end

dist{T}(XX::Rel{Iso{T}}) =
    begin
        K = Rel{T}
        ptr, Xs = data(XX)
        return Iso{K}(K(ptr, T[data(X) for X in Xs]))
    end
dist{T}(XX::Rel{Opt{T}}) =
    begin
        K = Rel{T}
        ptr, Xs = data(XX)
        if isnull(Xs[ptr])
            return Opt{K}()
        else
            LXs = sub(Xs, 1:ptr)
            RXs = sub(Xs, ptr+1:endof(Xs))
            vals = T[]
            for X in LXs
                if !isnull(X)
                    push!(vals, get(X))
                else
                    ptr -= 1
                end
            end
            for X in RXs
                if !isnull(X)
                    push!(vals, get(X))
                end
            end
            return Opt{K}(K(ptr, vals))
        end
    end
dist{T}(XX::Rel{Seq{T}}) =
    begin
        K = Rel{T}
        ptr, Xs = data(XX)
        if isempty(Xs)
            return Seq{K}(K{T}[])
        else
            vals = T[]
            lptr = 0
            rptr = 0
            for n in eachindex(Xs)
                if n == ptr
                    lptr = endof(vals)+1
                end
                append!(vals, data(Xs[n]))
                if n == ptr
                    rptr = endof(vals)
                end
            end
            return Seq{K}(K[K(n, vals) for n=lptr:rptr])
        end
    end

dist{Ns,Vs,T}(XX::Env{Ns,Vs,Iso{T}}) =
    begin
        K = Env{Ns,Vs,T}
        env, X = data(XX)
        return Iso{K}(K(env, data(X)))
    end
dist{Ns,Vs,T}(XX::Env{Ns,Vs,Opt{T}}) =
    begin
        K = Env{Ns,Vs,T}
        env, X = data(XX)
        return isnull(X) ? Opt{K}() : Opt{K}(K(env, get(X)))
    end
dist{Ns,Vs,T}(XX::Env{Ns,Vs,Seq{T}}) =
    begin
        K = Env{Ns,Vs,T}
        env, X = data(XX)
        return Seq{K}(K[K(env, x) for x in X])
    end

dist{Ns,Vs,T}(XX::EnvRel{Ns,Vs,Iso{T}}) =
    begin
        K = EnvRel{Ns,Vs,T}
        env, (ptr, Xs) = data(XX)
        return Iso{K}(K(env, ptr, T[data(X) for X in Xs]))
    end
dist{Ns,Vs,T}(XX::EnvRel{Ns,Vs,Opt{T}}) =
    begin
        K = EnvRel{Ns,Vs,T}
        env, (ptr, Xs) = data(XX)
        if isnull(Xs[ptr])
            return Opt{K}()
        else
            LXs = sub(Xs, 1:ptr)
            RXs = sub(Xs, ptr+1:endof(Xs))
            vals = T[]
            for X in LXs
                if !isnull(X)
                    push!(vals, get(X))
                else
                    ptr -= 1
                end
            end
            for X in RXs
                if !isnull(X)
                    push!(vals, get(X))
                end
            end
            return Opt{K}(K(env, ptr, vals))
        end
    end
dist{Ns,Vs,T}(XX::EnvRel{Ns,Vs,Seq{T}}) =
    begin
        K = EnvRel{Ns,Vs,T}
        env, (ptr, Xs) = data(XX)
        if isempty(Xs)
            return Seq{K}(K{T}[])
        else
            vals = T[]
            lptr = 0
            rptr = 0
            for n in eachindex(Xs)
                if n == ptr
                    lptr = endof(vals)+1
                end
                append!(vals, data(Xs[n]))
                if n == ptr
                    rptr = endof(vals)
                end
            end
            return Seq{K}(K[K(env, n, vals) for n=lptr:rptr])
        end
    end


#
# Flatten output: M_1{M_2{T}} -> M{T}.
#

flat{T}(XX::Iso{Iso{T}}) = data(XX)
flat{T}(XX::Iso{Opt{T}}) = data(XX)
flat{T}(XX::Iso{Seq{T}}) = data(XX)

flat{T}(XX::Opt{Iso{T}}) = isnull(XX) ? Opt{T}() : Opt{T}(data(get(XX)))
flat{T}(XX::Opt{Opt{T}}) = isnull(XX) || isnull(get(XX)) ? Opt{T}() : Opt{T}(get(get(XX)))
flat{T}(XX::Opt{Seq{T}}) = isnull(XX) ? Seq{T}(T[]) : get(XX)

flat{T}(XX::Seq{Iso{T}}) = Seq{T}(T[data(X) for X in XX])
flat{T}(XX::Seq{Opt{T}}) =
    let vals = T[]
        for X in XX
            if !isnull(X)
                push!(vals, get(X))
            end
        end
        Seq{T}(vals)
    end
flat{T}(XX::Seq{Seq{T}}) =
    let vals = T[]
        for X in XX
            append!(vals, data(X))
        end
        Seq{T}(vals)
    end


#
# Evaluation.
#

codegen{I<:Kind,I0<:Kind}(F, ::Type{I0}, X, ::Type{I}) =
    if I <: I0
        codegen(F, X, I0)
    else
        codegen(F, :( lift($I0, $X) ), I0)
    end

codegen(F, X, I) = F(X, I)

#
# Mapping over a structure.
#

codegen_map{I<:Kind,O<:Kind,K<:Kind}(F, ::Type{I}, ::Type{O}, XX, ::Type{Iso{K}}) =
    quote
        Iso{$O}($(codegen(F, I, :( data($XX) ), K)))
    end

codegen_map{I<:Kind,O<:Kind,K<:Kind}(F, ::Type{I}, ::Type{O}, XX, ::Type{Opt{K}}) =
    let
        @gensym xx
        quote
            $xx = data($XX)::Nullable{$K}
            isnull($xx) ? Opt{$O}() : Opt{$O}($(codegen(F, I, :( get($xx) ), K)))
        end
    end

codegen_map{I<:Kind,O<:Kind,K<:Kind}(F, ::Type{I}, ::Type{O}, XX, ::Type{Seq{K}}) =
    let
        @gensym X
        quote
            Seq{$O}($O[$(codegen(F, I, X, K)) for $X in data($XX) ])
        end
    end

codegen_map{I<:Kind,O<:Kind,K<:Kind}(F, ::Type{I}, ::Type{O}, XX, ::Type{Rel{K}}) =
    let
        @gensym ptr X Xs
        quote
            $ptr, $Xs = data($XX)::RelData{$K}
            Rel{$O}($ptr, $O[$(codegen(F, I, X, K)) for $X in $Xs])
        end
    end

codegen_map{I<:Kind,O<:Kind,Ns,Vs,K<:Kind}(F, ::Type{I}, ::Type{O}, XX, ::Type{Env{Ns,Vs,K}}) =
    let
        @gensym env X
        quote
            $env, $X = data($XX)::EnvData{$Ns,$Vs,$K}
            Env{$Ns,$Vs,$O}($env, $(codegen(F, I, X, K)))
        end
    end

codegen_map{I<:Kind,O<:Kind,Ns,Vs,K<:Kind}(F, ::Type{I}, ::Type{O}, XX, ::Type{EnvRel{Ns,Vs,K}}) =
    let
        @gensym env ptr X Xs
        quote
            $env, ($ptr, $Xs) = data($XX)::EnvRelData{$Ns,$Vs,$K}
            EnvRel{$Ns,$Vs,$O}($env, $ptr, $O[$(codegen(F, I, X, K)) for $X in $Xs])
        end
    end


#
# Composition.
#

codegen_compose{I<:Kind,I1<:Kind,O1<:Kind,I2<:Kind,O2<:Kind}(
    G, ::Type{I2}, ::Type{O2}, F, ::Type{I1}, ::Type{O1}, X, ::Type{I}) =
    begin
        I2I1 = Kind(I2, I1)
        O1I2 = Kind(O1, I2)
        @gensym XX XY YX YY Y
        quote
            $XX = dup($I2I1, $X)
            $XY = $( codegen_map(F, I1, O1, XX, I2I1) )
            $YX = dist($XY)
            $YY = $( codegen_map(G, I2, O2, YX, O1I2) )
            $Y = flat($YY)
            $Y
        end
    end

# Faster shortcuts.

codegen_compose{A,B,C}(G, ::Type{Iso{B}}, ::Type{Iso{C}}, F, ::Type{Iso{A}}, ::Type{Iso{B}}, X, ::Type{Iso{A}}) =
    codegen(G, Iso{B}, codegen(F, Iso{A}, X, Iso{A}), Iso{B})

codegen_compose{A,B,C}(G, ::Type{Iso{B}}, ::Type{Iso{C}}, F, ::Type{Iso{A}}, ::Type{Seq{B}}, X, ::Type{Iso{A}}) =
    begin
        @gensym Y
        quote
            Seq{$C}(
                $C[data($(codegen(G, Iso{B}, :( Iso{$B}($Y) ), Iso{B}))) for $Y in $(codegen(F, Iso{A}, X, Iso{A}))])
        end
    end

