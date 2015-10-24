
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
        input = Iso{I}
        output = Seq{O}
        pipe = SetPipe{I, O}(name, self.db.instance.sets[name])
        query = Query(scope, O, input=input, output=output, pipe=pipe)
        select =
            class.select != nothing ? class.select : tuple(keys(class.arrows)...)
        item, cap = mkselect(query, select)
        items = isa(item, Tuple) ? item : nothing
        query = Query(query, cap=cap, items=items)
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
    if name in keys(class.arrows)
        arrow = class.arrows[name]
        map = self.db.instance.maps[(self.name, arrow.name)]
        I = Entity{self.name}
        O = arrow.T
        input = Iso{I}
        if !arrow.plural && !arrow.partial
            output = Iso{O}
            pipe = IsoMapPipe{I, O}(name, map)
        elseif !arrow.plural
            output = Opt{O}
            pipe = OptMapPipe{I, O}(name, map)
        else
            output = Seq{O}
            pipe = SeqMapPipe{I, O}(name, map)
        end
        if O <: Entity
            targetname = classname(O)
            targetclass = self.db.schema.classes[targetname]
            scope = ClassScope(self.db, targetname)
            query = Query(scope, O, input=input, output=output, pipe=pipe)
            select =
                arrow.select != nothing ? arrow.select :
                targetclass.select != nothing ? targetclass.select :
                    tuple(keys(targetclass.arrows)...)
            item, cap = mkselect(query, select)
            items = isa(item, Tuple) ? item : nothing
            query = Query(query, cap=cap, items=items)
        else
            scope = EmptyScope(self.db)
            query = Query(scope, O, input=input, output=output, pipe=pipe)
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


function mkselect(state::Query, select::Symbol)
    op = lookup(state, select)
    @assert !isnull(op)
    op = get(op)
    return op, finalize(op)
end

function mkselect(state::Query, select::Tuple)
    items = ()
    ops = ()
    for field in select
        item, op = mkselect(state, field)
        items = (items..., item)
        ops = (ops..., op)
    end
    I = codomain(state)
    O = Tuple{map(op -> datatype(op.output), ops)...}
    input = Iso{I}
    output = Iso{O}
    scope = empty(state)
    pipe = TuplePipe{I,O}([op.pipe for op in ops])
    cup = Query(scope, O, input=input, output=output, pipe=pipe)
    return items, cup
end


scope(db::Database) = RootScope(db)

