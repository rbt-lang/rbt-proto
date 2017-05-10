#
# Abstract syntax tree.
#


# Syntax node.

immutable Syntax
    src::Any
    val::Any
    label::Symbol
    args::Vector{Syntax}
end

Syntax(src, val) =
    Syntax(src, val, NO_LABEL, NO_ARGS)

Syntax(src, label::Symbol, ::Void) =
    Syntax(src, nothing, label, NO_ARGS)

Syntax(src, label::Symbol, args::Vector{Syntax}) =
    Syntax(src, nothing, label, args)

const NO_LABEL = Symbol("")
const NO_ARGS = Syntax[]

haslabel(syn::Syntax) =
    syn.label != NO_LABEL

hasargs(syn::Syntax) =
    syn.args != NO_ARGS

source(syn::Syntax) = syn.src

value(syn::Syntax) = syn.val

label(syn::Syntax) = syn.label

start(syn::Syntax) = 1
next(syn::Syntax, st) = (syn.args[st], st+1)
done(syn::Syntax, st) = st > length(syn.args)
length(syn::Syntax) = length(syn.args)
isempty(syn::Syntax) = isempty(syn.args) : true

function show(io::IO, syn::Syntax)
    if syn.src !== nothing
        print(io, syn.src)
    elseif !haslabel(syn)
        print(io, syn.val)
    else
        print(io, syn.label)
        if hasargs(syn)
            print(io, "(")
            comma = false
            for arg in syn.args
                if comma
                    print(io, ", ")
                end
                comma = true
                print(io, arg)
            end
            print(io, ")")
        end
    end
end

Syntax(syn::Syntax) = syn

Syntax(ex) =
    expr2syntax(parse(string("(", ex, ")")))


# Parses a Julia expression as a Rabbit query.

expr2syntax(ex) =
    Syntax(ex, ex)

expr2syntax(ex::Symbol) =
    ex == :null ?
        Syntax(ex, nothing) :
        Syntax(ex, ex, nothing)

expr2syntax(ex::QuoteNode) =
    Syntax(ex.value, ex.value, nothing)

function expr2syntax(ex::Expr)
    if ex.head == :(:) && length(ex.args) >= 2
        head = length(ex.args) > 2 ?
            Expr(:(:), ex.args[1:end-1]...) :
            ex.args[1]
        syn = expr2syntax(head)
        call, tail = destructcolon(ex.args[end])
        syn =
            if isa(call, Symbol)
                Syntax(Expr(:(:), ex.args[1:end-1]..., call), call, [syn])
            elseif isa(call, Expr) && call.head == :call && isa(call.args[1], Symbol)
                args = Vector{Syntax}(length(call.args))
                args[1] = syn
                for k = 2:endof(args)
                    args[k] = expr2syntax(call.args[k])
                end
                Syntax(Expr(:(:), ex.args[1:end-1]..., call), call.args[1], args)
            else
                error("invalid query postfix notation: $ex")
            end
        if tail !== nothing
            syn = Syntax(ex, :(.), [syn, expr2syntax(tail)])
        end
        return syn
    elseif ex.head == :call && isa(ex.args[1], Symbol)
        args = Vector{Syntax}(length(ex.args)-1)
        for k in eachindex(args)
            args[k] = expr2syntax(ex.args[k+1])
        end
        return Syntax(ex, ex.args[1], args)
    elseif ex.head == :call
        return expr2syntax(destructcall(ex.args[1], ex.args[2:end]))
    elseif ex.head == :(.) || ex.head == :(=>)
        return Syntax(ex, ex.head, [expr2syntax(arg) for arg in ex.args])
    elseif ex.head == :(&&)
        return Syntax(ex, :(&), [expr2syntax(arg) for arg in ex.args])
    elseif ex.head == :(||)
        return Syntax(ex, :(|), [expr2syntax(arg) for arg in ex.args])
    elseif ex.head == :ref
        return Syntax(ex, :get, [expr2syntax(arg) for arg in ex.args])
    elseif ex.head == :vect
        return Syntax(ex, :array, [expr2syntax(arg) for arg in ex.args])
    elseif ex.head == :quote && length(ex.args) == 1
        return expr2syntax(ex.args[1])
    elseif ex.head == :comparison && length(ex.args) >= 3 && isa(ex.args[2], Symbol)
        syn = expr2syntax(Expr(:call, ex.args[2], ex.args[1], ex.args[3]))
        if length(ex.args) > 3
            syn = Syntax(ex, :(&), op, expr2syntax(Expr(:comparison, ex.args[3:end]...)))
        end
        return syn
    elseif ex.head == :macrocall && length(ex.args) == 2 && ex.args[1] == Symbol("@r_str")
        return Syntax(ex, eval(ex))
    else
        error("invalid query notation: $ex")
    end
end

destructcall(ex::QuoteNode, args) =
    Expr(:call, ex.value, args...)

destructcall(ex::Expr, args) =
    if ex.head == :quote && length(ex.args) == 1
        Expr(:call, ex.args[1], args...)
    else
        Expr(ex.head, ex.args[1:end-1]..., destructcall(ex.args[end], args))
    end

destructcall(ex, args) =
    error("invalid query call notation: $ex")

destructcolon(ex) =
    if isa(ex, Expr) && ex.head == :(.) && length(ex.args) == 2
        destructcolon(ex.args[1], ex.args[2])
    elseif (isa(ex, Expr) && ex.head == :call && length(ex.args) == 2 &&
            isa(ex.args[1], Expr) && ex.args[1].head == :(.) && length(ex.args[1].args) == 2)
        destructcolon(ex.args[1].args[1], Expr(:call, ex.args[1].args[2], ex.args[2]))
    else
        ex, nothing
    end

destructcolon(ex, tail) =
    if isa(ex, Expr) && ex.head == :(.) && length(ex.args) == 2
        destructcolon(ex.args[1], Expr(:(.), ex.args[2], tail))
    elseif (isa(ex, Expr) && ex.head == :call && length(ex.args) == 2 &&
            isa(ex.args[1], Expr) && ex.args[1].head == :(.) && length(ex.args[1].args) == 2)
        destructcolon(ex.args[1].args[1], Expr(:call, ex.args[1].args[2], Expr(:(.), ex.args[2], tail)))
    else
        ex, tail
    end

