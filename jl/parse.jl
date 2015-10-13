
module Parse

export
    @q_str,
    query,
    Syntax,
    LiteralType,
    LiteralSyntax,
    ApplySyntax,
    ComposeSyntax

import Base: show


abstract Syntax


const LiteralType = Union{Void,Int,Float64,AbstractString}

immutable LiteralSyntax{T<:LiteralType} <: Syntax
    val::T
end

show(io::IO, ::LiteralSyntax{Void}) = print(io, "null")
show(io::IO, syn::LiteralSyntax) = show(io, syn.val)


immutable ApplySyntax <: Syntax
    fn::Symbol
    args::Vector{Syntax}
end

show(io::IO, syn::ApplySyntax) =
    if isempty(syn.args)
        print(io, syn.fn)
    else
        print(io, syn.fn, "(", join(syn.args, ","), ")")
    end


immutable ComposeSyntax <: Syntax
    f::Syntax
    g::Syntax
end

show(io::IO, syn::ComposeSyntax) = print(io, syn.f, ".", syn.g)


macro q_str(str)
    query(str)
end


query(str::AbstractString) =
    ex2syn(parse(string("(", str, ")")))


ex2syn(ex::Symbol) = ex == :null ? LiteralSyntax(nothing) : ApplySyntax(ex, [])
ex2syn(ex::QuoteNode) = ApplySyntax(ex.value, [])
ex2syn(ex::LiteralType) = LiteralSyntax(ex)

function ex2syn(ex::Expr)
    if ex.head == :(.) && length(ex.args) == 2
        return ComposeSyntax(map(ex2syn, ex.args)...)
    elseif ex.head == :(:) && length(ex.args) >= 2
        syn = ex2syn(ex.args[1])
        for ex in ex.args[2:end]
            tail = nothing
            while isa(ex, Expr) && ex.head == :(.) && length(ex.args) == 2
                tail = tail == nothing ? ex2syn(ex.args[2]) : ComposeSyntax(ex2syn(ex.args[2]), tail)
                ex = ex.args[1]
            end
            if isa(ex, Symbol)
                syn = ApplySyntax(ex, [syn])
            elseif isa(ex, Expr) && ex.head == :call && isa(ex.args[1], Symbol)
                args = Syntax[syn]
                append!(args, map(ex2syn, ex.args[2:end]))
                syn = ApplySyntax(ex.args[1], args)
            else
                error("not a query (:) expression: $ex")
            end
            if tail != nothing
                syn = ComposeSyntax(syn, tail)
            end
        end
        return syn
    elseif ex.head == :call && isa(ex.args[1], Symbol)
        return ApplySyntax(ex.args[1], map(ex2syn, ex.args[2:end]))
    elseif ex.head == :call
        return ex2syn(pushcall(ex.args[1], ex.args[2:end]))
    elseif ex.head == :comparison && length(ex.args) == 3 && isa(ex.args[2], Symbol)
        return ApplySyntax(ex.args[2], Syntax[ex2syn(ex.args[1]), ex2syn(ex.args[3])])
    else
        error("not a query expression: $ex")
    end
end

pushcall(ex::QuoteNode, args) =
    Expr(:call, ex.value, args...)

pushcall(ex::Expr, args) =
    Expr(ex.head, ex.args[1:end-1]..., pushcall(ex.args[end], args))

pushcall(ex, args) =
    error("not a query call expression: $ex")

end

