
const LiteralType = Union{Void,Int,Float64,AbstractString}

immutable LiteralSyntax{T<:LiteralType} <: AbstractSyntax
    val::T
end

show(io::IO, ::LiteralSyntax{Void}) = print(io, "null")
show(io::IO, syntax::LiteralSyntax) = show(io, syntax.val)


immutable ApplySyntax <: AbstractSyntax
    fn::Symbol
    args::Vector{AbstractSyntax}
end

show(io::IO, syntax::ApplySyntax) =
    if isempty(syntax.args)
        print(io, syntax.fn)
    else
        print(io, syntax.fn, "(", join(syntax.args, ","), ")")
    end


immutable ComposeSyntax <: AbstractSyntax
    f::AbstractSyntax
    g::AbstractSyntax
end

show(io::IO, syntax::ComposeSyntax) = print(io, syntax.f, ".", syntax.g)


syntax(str::AbstractString) =
    ex2syn(parse(string("(", str, ")")))

syntax(ex::Union{Symbol,QuoteNode,LiteralType,Expr}) =
    ex2syn(parse(string("(", ex, ")")))


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
                args = AbstractSyntax[syn]
                append!(args, map(ex2syn, ex.args[2:end]))
                syn = ApplySyntax(ex.args[1], args)
            else
                error("invalid postfix notation: $ex")
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
        return ApplySyntax(ex.args[2], AbstractSyntax[ex2syn(ex.args[1]), ex2syn(ex.args[3])])
    else
        error("invalid syntax: $ex")
    end
end

pushcall(ex::QuoteNode, args) =
    Expr(:call, ex.value, args...)

pushcall(ex::Expr, args) =
    Expr(ex.head, ex.args[1:end-1]..., pushcall(ex.args[end], args))

pushcall(ex, args) =
    error("invalid call syntax: $ex")

