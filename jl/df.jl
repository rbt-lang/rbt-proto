
immutable NullToNAPipe <: AbstractPipe
    F::AbstractPipe
    input::Input
    output::Output

    NullToVoidPipe(F::AbstractPipe) =
        begin
            if isnonempty(F)
                return F
            end
            F = OptPipe(F)
            output = Output(Union{odomain(F),NAType}, omode(F))
            output = Output(output, ltotal=true, runique=false)
            return new(F, input(F), output)
        end
end

show(io::IO, pipe::NullToNAPipe) = show(io, pipe.F)

arms(pipe::NullToNAPipe) = AbstractPipe[pipe.F]

codegen(pipe::NullToNAPipe, X, I) =
    let T = odomain(pipe)
        @gensym Y
        quote
            $Y = $(codegen(pipe.F, X, I))
            isnull($Y) ? Iso{$T}(NA) : Iso{$T}(get($Y))
        end
    end


immutable DataFramePipe <: AbstractPipe
    F::AbstractPipe
    G::TuplePipe
    tags::Vector{Symbol}
    input::Input
    output::Output

    DataFramePipe(F::AbstractPipe, tagged_Gs::Vector{TaggedPipe}) =
        begin
            F = SeqPipe(F)
            G = TuplePipe(AbstractPipe[G0 for (tag, G0) in tagged_Gs])
            @assert(
                odomain(F) <: idomain(G),
                "$(repr(F)) and $(repr(G)) are not composable")
            tags = Symbol[tag for (tag, G0) in tagged_Gs]
            input = RBT.input(F >> G)
            output = Output(DataFrame)
            return new(F, G, tags, input, output)
        end
end

DataFramePipe(F, tagged_Gs) = DataFramePipe(F, TaggedPipe[TaggedPipe(tag, G) for (tag, G) in tagged_Gs])
DataFramePipe(F, tagged_Gs::Pair{Symbol}...) = DataFramePipe(F, tagged_Gs)

show(io::IO, pipe::DataFramePipe) =
    print(io, "DataFrame($(pipe.F), $(pipe.G))")

arms(pipe::DataFramePipe) = AbstractPipe[pipe.F, pipe.G]

codegen(pipe::DataFramePipe, X, I) =
    begin
        @gensym cols Y0 y idx
        Y = codegen_compose(pipe.G, pipe.F, X, I)
        return quote
            $Y0 = $Y
            $cols = Any[
                $([
                    let T = odomain(F)
                        isplural(F) ?
                            :( Vector{Vector{$T}}() ) :
                        ispartial(F) ?
                            :( DataVector{$T}([]) ) :
                            :( Vector{$T}() )
                    end
                    for F in pipe.G.Fs
                ]...)
            ]
            for $y in $Y0
                $([
                    isplural(F) ?
                        :( push!($cols[$idx], $y[$idx]) ) :
                    ispartial(F) ?
                        :( push!($cols[$idx], isnull($y[$idx]) ? NA : get($y[$idx])) ) :
                        :( push!($cols[$idx], $y[$idx]) )
                    for (idx, F) in enumerate(pipe.G.Fs)
                ]...)
            end
            Iso(DataFrame($cols, $(pipe.tags)))
        end
    end


compile(fn::Fn(:dataframe), base::Scope, flow::AbstractSyntax, ops::AbstractSyntax...) =
    let flow = compile(base, flow),
        ops = [compile(flow, op) for op in ops]
        isempty(ops) ? compile(fn, base, flow) : compile(fn, base, compile(Fn{:select}, base, flow, ops...))
    end


function compile(::Fn(:dataframe), base::Scope, flow::Query)
    flow = select(flow)
    if !isnull(flow.scope.items)
        fields = mkdffields(flow)
        pipe = DataFramePipe(flow.pipe, fields)
        return Query(nest(base, DataFrame), pipe)
    else
        flow = select(flow)
        if ispartial(flow)
            pipe = OptToNAPipe(flow.pipe)
            flow = Query(flow, pipe=pipe)
        end
    end
    return flow
end


function mkdffields(flow::Query)
    fields = ()
    for item in get(flow.scope.items)
        field = item(flow.scope)
        if !isnull(field.scope.items)
            fields = (fields..., mkdffields(field)...)
        else
            name = get(field.scope.tag, symbol(""))
            if !issingular(field)
                field = compile(Fn{:dataframe}, flow.scope, field)
            end
            F = field.pipe
            fields = (fields..., (name, F))
        end
    end
    return fields
end

