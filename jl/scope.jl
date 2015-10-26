
immutable RootScope <: AbstractScope
    db::Database
end

show(io::IO, ::RootScope) = print(io, "ROOT")

root(self::RootScope) = self

empty(self::RootScope) = EmptyScope(self.db)

function lookup(self::RootScope, name::Symbol)
    if name in keys(self.db.schema.classes)
        class = self.db.schema.classes[name]
        scope = ClassScope(self.db, name)
        I = UnitType
        O = Entity{name}
        input = Input(I)
        output = Output(O, singular=false, complete=false, exclusive=true, reachable=true)
        pipe = SetPipe{I, O}(name, self.db.instance.sets[name])
        tag = NullableSymbol(name)
        src = NullableSyntax(ApplySyntax(name, []))
        query = Query(scope, input=input, output=output, pipe=pipe, tag=tag, src=src)
        selector = mkselect(
            query,
            class.select != nothing ? class.select : tuple(keys(class.arrows)...))
        identity = mkidentity(query, :id)
        query = Query(query, selector=selector, identity=identity)
        return NullableQuery(query)
    else
        return NullableQuery()
    end
end


immutable ClassScope <: AbstractScope
    db::Database
    name::Symbol
end

show(io::IO, self::ClassScope) = print(io, "Class(<", self.name, ">)")

root(self::ClassScope) = RootScope(self.db)

empty(self::ClassScope) = EmptyScope(self.db)

function lookup(self::ClassScope, name::Symbol)
    class = self.db.schema.classes[self.name]
    if name == :id
        scope = EmptyScope(self.db)
        I = Entity{self.name}
        input = Input(I)
        output = Output(Int, exclusive=true)
        pipe = IsoFieldPipe{I,Int}(:id)
        tag = NullableSymbol(name)
        src = NullableSyntax(ApplySyntax(name, []))
        return NullableQuery(Query(scope, input=input, output=output, pipe=pipe, tag=tag, src=src))
    elseif name in keys(class.arrows)
        tag = NullableSymbol(name)
        arrow = class.arrows[name]
        map = self.db.instance.maps[(self.name, arrow.name)]
        I = Entity{self.name}
        O = domain(arrow.output)
        input = Input(I)
        output = arrow.output
        if singular(arrow.output) && complete(arrow.output)
            pipe = IsoMapPipe{I, O}(name, map)
        elseif singular(arrow.output)
            pipe = OptMapPipe{I, O}(name, map)
        else
            pipe = SeqMapPipe{I, O}(name, map)
        end
        src = NullableSyntax(ApplySyntax(name, []))
        if O <: Entity
            targetname = classname(O)
            targetclass = self.db.schema.classes[targetname]
            scope = ClassScope(self.db, targetname)
            query = Query(scope, input=input, output=output, pipe=pipe, tag=tag, src=src)
            selector = mkselect(
                query,
                arrow.select != nothing ? arrow.select :
                targetclass.select != nothing ? targetclass.select :
                    tuple(keys(targetclass.arrows)...))
            identity = mkidentity(query, :id)
            query = Query(query, selector=selector, identity=identity)
        else
            scope = EmptyScope(self.db)
            query = Query(scope, input=input, output=output, pipe=pipe, tag=tag, src=src)
        end
        return NullableQuery(query)
    else
        return NullableQuery()
    end
end


immutable EmptyScope <: AbstractScope
    db::Database
end

show(io::IO, ::EmptyScope) = print(io, "EMPTY")

root(self::EmptyScope) = RootScope(self.db)

empty(self::EmptyScope) = self

lookup(::EmptyScope, ::Symbol) = NullableQuery()


mkselect(state::Query, spec) = mkcomposite(state, spec, :selector)

mkidentity(state::Query, spec) = mkcomposite(state, spec, :identity)

function mkcomposite(state::Query, name::Symbol, field)
    op = lookup(state, name)
    @assert !isnull(op)
    op = get(op)
    cap = getfield(op, field)
    if !isnull(cap)
        cap = get(cap)
        op = Query(op >> cap, parts=op.parts)
    end
    return op
end

function mkcomposite(state::Query, parts::Tuple, field)
    parts = tuple([mkcomposite(state, part, field) for part in parts]...)
    I = codomain(state)
    O = Tuple{[datatype(part.output) for part in parts]...}
    input = Input(I)
    output = Output(O)
    scope = empty(state)
    pipe = TuplePipe{I,O}([part.pipe for part in parts])
    return Query(scope, input=input, output=output, pipe=pipe, parts=parts)
end


scope(db::Database) = RootScope(db)

