
immutable RootScope <: AbstractScope
    db::Database
    params::Dict{Symbol,Any}
end

show(io::IO, ::RootScope) = print(io, "ROOT")

root(self::RootScope) = self

empty(self::RootScope) = EmptyScope(self.db, self.params)

function lookup(self::RootScope, name::Symbol)
    if name in keys(self.params)
        return NullableQuery(val2q(self, self.params[name]))
    end
    if name in keys(self.db.schema.name2class)
        class = self.db.schema.name2class[name]
        scope = ClassScope(self.db, name, self.params)
        I = UnitType
        O = Entity{name}
        input = Input(I)
        output = Output(O, singular=false, complete=false, exclusive=true, reachable=true)
        pipe = SetPipe{I, O}(name, self.db.instance.sets[name])
        tag = NullableSymbol(name)
        syntax = NullableSyntax(ApplySyntax(name, []))
        query = Query(scope, input=input, output=output, pipe=pipe, tag=tag, syntax=syntax)
        selector = mkselector(
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
    params::Dict{Symbol,Any}
end

show(io::IO, self::ClassScope) = print(io, "Class(<", self.name, ">)")

root(self::ClassScope) = RootScope(self.db, self.params)

empty(self::ClassScope) = EmptyScope(self.db, self.params)

function lookup(self::ClassScope, name::Symbol)
    if name in keys(self.params)
        return NullableQuery(val2q(self, self.params[name]))
    end
    class = self.db.schema.name2class[self.name]
    if name == :id
        scope = EmptyScope(self.db, self.params)
        I = Entity{self.name}
        input = Input(I)
        output = Output(Int, exclusive=true)
        pipe = FieldPipe{I,Int}(:id)
        tag = NullableSymbol(name)
        syntax = NullableSyntax(ApplySyntax(name, []))
        return NullableQuery(Query(scope, input=input, output=output, pipe=pipe, tag=tag, syntax=syntax))
    elseif name in keys(class.name2arrow)
        tag = NullableSymbol(name)
        arrow = class.name2arrow[name]
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
        syntax = NullableSyntax(ApplySyntax(name, []))
        if O <: Entity
            targetname = classname(O)
            targetclass = self.db.schema.name2class[targetname]
            scope = ClassScope(self.db, targetname, self.params)
            query = Query(scope, input=input, output=output, pipe=pipe, tag=tag, syntax=syntax)
            selector = mkselector(
                query,
                arrow.select != nothing ? arrow.select :
                targetclass.select != nothing ? targetclass.select :
                    tuple(keys(targetclass.arrows)...))
            identity = mkidentity(query, :id)
            query = Query(query, selector=selector, identity=identity)
        else
            scope = EmptyScope(self.db, self.params)
            query = Query(scope, input=input, output=output, pipe=pipe, tag=tag, syntax=syntax)
        end
        return NullableQuery(query)
    else
        return NullableQuery()
    end
end


immutable EmptyScope <: AbstractScope
    db::Database
    params::Dict{Symbol,Any}
end

show(io::IO, ::EmptyScope) = print(io, "EMPTY")

root(self::EmptyScope) = RootScope(self.db, self.params)

empty(self::EmptyScope) = self

lookup(self::EmptyScope, name::Symbol) =
    name in keys(self.params) ?
        NullableQuery(val2q(self, self.params[name])) :
        NullableQuery()


mkselector(base::Query, spec) = mkcomposite(base, spec, :selector)

mkidentity(base::Query, spec) = mkcomposite(base, spec, :identity)

function mkcomposite(base::Query, query::Query, field)
    cap = getfield(query, field)
    if !isnull(cap)
        query = Query(query >> get(cap), tag=query.tag)
    end
    return query
end

function mkcomposite(base::Query, name::Symbol, field)
    op = lookup(base, name)
    @assert !isnull(op)
    return mkcomposite(base, get(op), field)
end

function mkcomposite(base::Query, parts::Tuple, field)
    ops = [mkcomposite(base, part, field) for part in parts]
    return record(base, ops...)
end

function val2q(base::AbstractScope, val)
    if isa(val, AbstractString)
        val = UTF8String(val)
    end
    scope = empty(base)
    I = isa(base, ClassScope) ? Entity{base.name} : UnitType
    O = typeof(val)
    input = Input(I)
    output = Output(O, complete=(val != nothing))
    pipe = val != nothing ? ConstPipe{I,O}(val) : NullVal{I}()
    return Query(scope, input=input, output=output, pipe=pipe)
end

scope(db::Database) = RootScope(db, Dict{Symbol,Any}())

scope(db::Database, params::Dict{Symbol,Any}) = RootScope(db, params)

