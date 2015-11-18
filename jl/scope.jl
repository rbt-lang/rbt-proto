
immutable RootScope <: AbstractScope
    db::Database
    params::Dict{Symbol,Type}
end

show(io::IO, ::RootScope) = print(io, "ROOT")

root(self::RootScope) = self

empty(self::RootScope) = EmptyScope(self.db, self.params)

function lookup(self::RootScope, name::Symbol)
    if name in keys(self.params)
        return NullableQuery(param2q(self, name, self.params[name]))
    end
    if name in keys(self.db.schema.name2class)
        class = self.db.schema.name2class[name]
        scope = ClassScope(self.db, name, self.params)
        T = Entity{name}
        input = Input(Unit)
        output = Output(T, singular=false, complete=false, exclusive=true, reachable=true)
        pipe = SetPipe(name, self.db.instance.sets[name])
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
    params::Dict{Symbol,Type}
end

show(io::IO, self::ClassScope) = print(io, "Class(<", self.name, ">)")

root(self::ClassScope) = RootScope(self.db, self.params)

empty(self::ClassScope) = EmptyScope(self.db, self.params)

function lookup(self::ClassScope, name::Symbol)
    if name in keys(self.params)
        return NullableQuery(param2q(self, name, self.params[name]))
    end
    class = self.db.schema.name2class[self.name]
    if name == :id
        scope = EmptyScope(self.db, self.params)
        IT = Entity{self.name}
        input = Input(IT)
        output = Output(Int, exclusive=true)
        pipe = FieldPipe(IT, :id, Iso{Int})
        tag = NullableSymbol(name)
        syntax = NullableSyntax(ApplySyntax(name, []))
        return NullableQuery(Query(scope, input=input, output=output, pipe=pipe, tag=tag, syntax=syntax))
    elseif name in keys(class.name2arrow)
        tag = NullableSymbol(name)
        arrow = class.name2arrow[name]
        map = self.db.instance.maps[(self.name, arrow.name)]
        IT = Entity{self.name}
        OT = domain(arrow.output)
        input = Input(IT)
        output = arrow.output
        if singular(arrow.output) && complete(arrow.output)
            pipe = IsoMapPipe(name, map)
        elseif singular(arrow.output)
            pipe = OptMapPipe(name, map)
        else
            pipe = SeqMapPipe(name, map)
        end
        syntax = NullableSyntax(ApplySyntax(name, []))
        if OT <: Entity
            targetname = classname(OT)
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
    params::Dict{Symbol,Type}
end

show(io::IO, ::EmptyScope) = print(io, "EMPTY")

root(self::EmptyScope) = RootScope(self.db, self.params)

empty(self::EmptyScope) = self

lookup(self::EmptyScope, name::Symbol) =
    name in keys(self.params) ?
        NullableQuery(param2q(self, name, self.params[name])) :
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

function param2q(base::AbstractScope, name::Symbol, T::Type)
    if T <: AbstractString
        T = UTF8String
    elseif T <: Nullable{ASCIIString}
        T = Nullable{UTF8String}
    elseif T <: Vector{ASCIIString}
        T = Vector{UTF8String}
    end
    if T == Void
        T = Nullable{Union{}}
    end
    scope = empty(base)
    IT = isa(base, ClassScope) ? Entity{base.name} : Unit
    input = Input(IT, params=(Pair{Symbol,Type}(name, T),))
    if T <: Nullable || T <: Vector
        output = Output(eltype(T), singular=(T<:Nullable), complete=false)
    else
        output = Output(T)
    end
    pipe =
        T <: Vector ? SeqParamPipe(IT, name, eltype(T)) :
        T <: Nullable ? OptParamPipe(IT, name, eltype(T)) : IsoParamPipe(IT, name, T)
    return Query(scope, input=input, output=output, pipe=pipe)
end

scope(db::Database) = RootScope(db, Dict{Symbol,Type}())

scope(db::Database, params::Dict{Symbol,Type}) = RootScope(db, params)

