#
# Syntax tree and parsing.
#


# Parsed query.
abstract AbstractSyntax

# Parse a query.
syntax(syntax::AbstractSyntax) = syntax

# Literal node.
typealias Scalar Union{Void,Int,Float64,AbstractString,Regex}

immutable LiteralSyntax <: AbstractSyntax
    val::Scalar
end

show(io::IO, syntax::LiteralSyntax) = print(io, syntax.val == nothing ? "null" : syntax.val)

# Combinator constructor.
immutable ApplySyntax <: AbstractSyntax
    fn::Symbol
    args::Vector{AbstractSyntax}
    postfix::Bool
end

ApplySyntax(fn) = ApplySyntax(fn, [], false)
ApplySyntax(fn, args) = ApplySyntax(fn, args, false)

show(io::IO, syntax::ApplySyntax) =
    if isempty(syntax.args)
        print(io, syntax.fn)
    elseif syntax.postfix
        if length(syntax.args) == 1
            print(io, syntax.args[1], ":", syntax.fn)
        else
            print(io, syntax.args[1], ":", syntax.fn, "(", join(syntax.args[2:end], ","), ")")
        end
    else
        print(io, syntax.fn, "(", join(syntax.args, ","), ")")
    end

# Composition of combinators.
immutable ComposeSyntax <: AbstractSyntax
    f::AbstractSyntax
    g::AbstractSyntax
end

show(io::IO, syntax::ComposeSyntax) = print(io, syntax.f, ".", syntax.g)

# Parsing.
syntax(str::AbstractString) =
    ex2syn(parse(string("(", str, ")")))
syntax(ex::Union{Symbol,QuoteNode,Scalar,Expr}) =
    ex2syn(parse(string("(", ex, ")")))

ex2syn(ex::Symbol) = ex == :null ? LiteralSyntax(nothing) : ApplySyntax(ex, [])
ex2syn(ex::QuoteNode) = ApplySyntax(ex.value, [])
ex2syn(ex::Scalar) = LiteralSyntax(ex)

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
            while isa(ex, Expr) && ex.head == :call && length(ex.args) == 2 &&
                    isa(ex.args[1], Expr) && ex.args[1].head == :(.) && length(ex.args[1].args) == 2
                tail =
                    tail == nothing ?
                        ex2syn(Expr(:call, ex.args[1].args[2], ex.args[2])) :
                        ComposeSyntax(ex2syn(Expr(:call, ex.args[1].args[2], ex.args[2])), tail)
                ex = ex.args[1].args[1]
            end
            if isa(ex, Symbol)
                syn = ApplySyntax(ex, [syn], true)
            elseif isa(ex, Expr) && ex.head == :call && isa(ex.args[1], Symbol)
                args = AbstractSyntax[syn]
                append!(args, map(ex2syn, ex.args[2:end]))
                syn = ApplySyntax(ex.args[1], args, true)
            else
                dump(ex)
                error("invalid query postfix notation: $ex")
            end
            if tail != nothing
                syn = ComposeSyntax(syn, tail)
            end
        end
        return syn
    elseif ex.head == :call && isa(ex.args[1], Symbol)
        return ApplySyntax(ex.args[1], map(ex2syn, ex.args[2:end]))
    elseif ex.head == :(=>)
        return ApplySyntax(:(=>), map(ex2syn, ex.args))
    elseif ex.head == :(&&)
        return ApplySyntax(:(&), map(ex2syn, ex.args))
    elseif ex.head == :(||)
        return ApplySyntax(:(|), map(ex2syn, ex.args))
    elseif ex.head == :ref
        return ApplySyntax(:get, map(ex2syn, ex.args))
    elseif ex.head == :vect
        return ApplySyntax(:array, map(ex2syn, ex.args))
    elseif ex.head == :call
        return ex2syn(pushcall(ex.args[1], ex.args[2:end]))
    elseif ex.head == :comparison && length(ex.args) >= 3 && isa(ex.args[2], Symbol)
        op = ApplySyntax(ex.args[2], AbstractSyntax[ex2syn(ex.args[1]), ex2syn(ex.args[3])])
        k = 3
        while length(ex.args) >= k+2
            op = ApplySyntax(
                :(&),
                AbstractSyntax[
                    op,
                    ApplySyntax(ex.args[k+1], AbstractSyntax[ex2syn(ex.args[k]), ex2syn(ex.args[k+2])])])
            k = k+2
        end
        return op
    elseif ex.head == :macrocall && length(ex.args) == 2 && ex.args[1] == Symbol("@r_str")
        return LiteralSyntax(eval(ex))
    else
        dump(ex)
        println(ex.head == :macrocall)
        println(length(ex.args) == 2)
        println(ex.args[1] == :@r_str)
        error("invalid query notation: $ex")
    end
end

pushcall(ex::QuoteNode, args) =
    Expr(:call, ex.value, args...)

pushcall(ex::Expr, args) =
    Expr(ex.head, ex.args[1:end-1]..., pushcall(ex.args[end], args))

pushcall(ex, args) =
    error("invalid query call notation: $ex")

