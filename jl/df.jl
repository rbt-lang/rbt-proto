
immutable OptToNAPipe{I,O} <: IsoPipe{I,Union{O,NAtype}}
    F::OptPipe{I,O}
end

show(io::IO, pipe::OptToNAPipe) =
    print(io, "OptToNA(<", pipe.F, ">)")

execute{I,O}(pipe::OptToNAPipe{I,O}, x::I) =
    let y = execute(pipe.F, x)::Nullable{O}
        isnull(y) ? NA : get(y)
    end


immutable IsoDataFramePipe{I} <: IsoPipe{I, DataFrame}
    F::IsoPipe{I}
    fields
end

show(io::IO, pipe::IsoDataFramePipe) =
    print(io, "IsoDataFrame(", pipe.F, ", ", join(pipe.fields, ", "), ")")

function execute{I}(pipe::IsoDataFramePipe, x::I)
    data = Any[]
    names = Symbol[]
    y = pipe.F(x)
    for (name, A, F) in pipe.fields
        push!(names, name)
        a = A()
        push!(a, F(y))
        push!(data, a)
    end
    return DataFrame(data, names)
end


immutable OptDataFramePipe{I} <: IsoPipe{I, DataFrame}
    F::OptPipe{I}
    fields
end

show(io::IO, pipe::OptDataFramePipe) =
    print(io, "OptDataFrame(", pipe.F, ", ", join(pipe.fields, ", "), ")")

function execute{I}(pipe::OptDataFramePipe, x::I)
    data = Any[]
    names = Symbol[]
    y = pipe.F(x)
    for (name, A, F) in pipe.fields
        push!(names, name)
        a = A()
        if !isnull(y)
            push!(a, F(get(y)))
        end
        push!(data, a)
    end
    return DataFrame(data, names)
end


immutable SeqDataFramePipe{I} <: IsoPipe{I, DataFrame}
    F::SeqPipe{I}
    fields
end

show(io::IO, pipe::SeqDataFramePipe) =
    print(io, "SeqDataFrame(", pipe.F, ", ", join(pipe.fields, ", "), ")")


function execute{I}(pipe::SeqDataFramePipe, x::I)
    data = Any[]
    names = Symbol[]
    ys = pipe.F(x)
    for (name, A, F) in pipe.fields
        push!(names, name)
        a = A([])
        for y in ys
            z = F(y)
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
    return DataFrame(data, names)
end


function compile(::Type{Fn{:dataframe}}, base::Query, flow::Query)
    flow = select(flow)
    if !isnull(flow.fields)
        fields = mkdffields(flow)
        I = domain(flow)
        output = Output(DataFrame)
        pipe =
            singular(flow) && complete(flow) ? IsoDataFramePipe{I}(flow.pipe, fields) :
            singular(flow) ? OptDataFramePipe{I}(flow.pipe, fields) :
            SeqDataFramePipe{I}(flow.pipe, fields)
        return Query(empty(flow), input=flow.input, output=output, pipe=pipe)
    else
        flow = select(flow)
        if singular(flow) && !complete(flow)
            I = domain(flow)
            O = codomain(flow)
            output = Output(O, exclusive=exclusive(flow), reachable=reachable(flow))
            pipe = OptToNAPipe{I,O}(flow.pipe)
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
            O = codomain(field)
            A = singular(field) && !complete(field) ? DataVector{O} : Vector{O}
            F = field.pipe
            fields = (fields..., (name, A, F))
        end
    end
    return fields
end

