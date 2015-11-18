
immutable OptToNAPipe{I,T} <: IsoPipe{I,Union{T,NAtype}}
    F::OptPipe{I,T}
end

show(io::IO, pipe::OptToNAPipe) =
    print(io, "OptToNA($(pipe.F))")

apply{I,T}(pipe::OptToNAPipe{I,T}, X::I) =
    let Y = apply(pipe.F, X)::Opt{O}
        isnull(Y) ? NA : get(Y)
    end


immutable IsoDataFramePipe{I} <: IsoPipe{I, DataFrame}
    F::AbstractPipe{I}
    fields
end

show(io::IO, pipe::IsoDataFramePipe) =
    print(io, "IsoDataFrame($(pipe.F), $(join(pipe.fields, ", ")))")

function apply{I}(pipe::IsoDataFramePipe{I}, X::I)
    data = Any[]
    names = Symbol[]
    Y = apply(pipe.F, X)
    for (name, A, F) in pipe.fields
        push!(names, name)
        a = A()
        push!(a, unwrap(apply(F, Y)))
        push!(data, a)
    end
    return Iso(DataFrame(data, names))
end


immutable OptDataFramePipe{I} <: IsoPipe{I, DataFrame}
    F::AbstractPipe{I}
    fields
end

show(io::IO, pipe::OptDataFramePipe) =
    print(io, "OptDataFrame($(pipe.F), $(join(pipe.fields, ", ")))")

function apply{I}(pipe::OptDataFramePipe{I}, X::I)
    data = Any[]
    names = Symbol[]
    Y = apply(pipe.F, X)
    for (name, A, F) in pipe.fields
        push!(names, name)
        a = A()
        if !isnull(y)
            push!(a, unwrap(apply(F, Iso(get(y)))))
        end
        push!(data, a)
    end
    return Iso(DataFrame(data, names))
end


immutable SeqDataFramePipe{I} <: IsoPipe{I, DataFrame}
    F::AbstractPipe{I}
    fields
end

show(io::IO, pipe::SeqDataFramePipe) =
    print(io, "SeqDataFrame($(pipe.F), $(join(pipe.fields, ", ")))")


function apply{I}(pipe::SeqDataFramePipe{I}, X::I)
    data = Any[]
    names = Symbol[]
    Y = apply(pipe.F, X)
    for (name, A, F) in pipe.fields
        push!(names, name)
        a = A([])
        for y in Y
            z = unwrap(apply(F, Iso(y)))
            if A <: DataVector
                if isnull(z)
                    push!(a, NA)
                else
                    push!(a, get(z))
                end
            else
                push!(a, z)
            end
        end
        push!(data, a)
    end
    return Iso(DataFrame(data, names))
end


function compile(::Fn(:dataframe), base::Query, flow::Query)
    flow = select(flow)
    if !isnull(flow.fields)
        fields = mkdffields(flow)
        output = Output(DataFrame)
        pipe =
            singular(flow) && complete(flow) ? IsoDataFramePipe(flow.pipe, fields) :
            singular(flow) ? OptDataFramePipe(flow.pipe, fields) :
            SeqDataFramePipe(flow.pipe, fields)
        return Query(empty(flow), input=flow.input, output=output, pipe=pipe)
    else
        flow = select(flow)
        if singular(flow) && !complete(flow)
            output = Output(O, exclusive=exclusive(flow), reachable=reachable(flow))
            pipe = OptToNAPipe(flow.pipe)
            flow = Query(flow, output=output, pipe=pipe)
        end
    end
    return flow
end


function mkdffields(flow::Query)
    fields = ()
    for field in get(flow.fields)
        if !isnull(field.fields)
            fields = (fields..., mkdffields(field.fields)...)
        else
            name = get(field.tag, symbol(""))
            if !singular(field)
                field = compile(Fn{:dataframe}, flow, field)
            end
            O = odomain(field)
            A = !singular(field) ? Vector{DataVector{O}} :
                singular(field) && !complete(field) ? DataVector{O} : Vector{O}
            F = field.pipe
            fields = (fields..., (name, A, F))
        end
    end
    return fields
end

