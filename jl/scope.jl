
immutable RootScope <: AbstractScope
    db::Database
    finish::Nullable{Query}
end

RootScope(db::Database) = RootScope(db, Nullable{Query}())

show(io::IO, ::RootScope) = print(io, "ROOT")

domain(::RootScope) = Tuple{}

root(state::RootScope) = scope

scalar(state::RootScope, T::DataType) = ScalarScope(state.db, T)

function lookup(state::RootScope, name::Symbol)
    if name in keys(state.db.schema.classes)
        class = state.db.schema.classes[name]
        I = domain(state)
        O = Entity{name}
        input = Iso{I}
        output = Seq{O}
        scope = ClassScope(state.db, name, Nullable{Query}())
        select = class.select
        if select == nothing
            select = tuple(keys(class.arrows)...)
        end
        finish = mkfinish(scope, select)
        scope = setfinish(scope, finish)
        pipe = SetPipe{I, O}(name, state.db.instance.sets[name])
        return Nullable{Query}(Query(input, output, scope, pipe))
    else
        return Nullable{Query}()
    end
end

getfinish(state::RootScope) = state.finish

setfinish(state::RootScope, finish::Query) =
    RootScope(state.db, Nullable{Query}(finish))


immutable ClassScope <: AbstractScope
    db::Database
    name::Symbol
    finish::Nullable{Query}
end

show(io::IO, state::ClassScope) = print(io, "Class(<", state.name, ">)")

domain(state::ClassScope) = Entity{state.name}

root(state::ClassScope) = RootScope(state.db)

scalar(state::ClassScope, T::DataType) = ScalarScope(state.db, T)

function lookup(state::ClassScope, name::Symbol)
    class = state.db.schema.classes[state.name]
    if name in keys(class.arrows)
        arrow = class.arrows[name]
        map = state.db.instance.maps[(state.name, arrow.name)]
        I = domain(state)
        O = arrow.T
        input = Iso{I}
        if O <: Entity
            targetname = classname(O)
            targetclass = state.db.schema.classes[targetname]
            select = arrow.select
            if select == nothing
                select = targetclass.select
            end
            if select == nothing
                select = tuple(keys(targetclass.arrows)...)
            end
            scope = ClassScope(state.db, classname(O), Nullable{Query}())
            finish = mkfinish(scope, select)
            scope = setfinish(scope, finish)
        else
            scope = ScalarScope(state.db, O)
        end
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
        return Nullable{Query}(Query(input, output, scope, pipe))
    else
        return Nullable{Query}()
    end
end

getfinish(state::ClassScope) =
    Nullable{Query}(state.finish)

setfinish(state::ClassScope, finish::Query) =
    ClassScope(state.db, state.name, finish)


immutable ScalarScope <: AbstractScope
    db::Database
    dom::DataType
    finish::Nullable{Query}
end

ScalarScope(db::Database, dom::DataType) =
    ScalarScope(db, dom, Nullable{Query}())

show(io::IO, state::ScalarScope) = print(io, "Scalar(", state.dom, ")")

domain(state::ScalarScope) = state.dom

root(state::ScalarScope) = RootScope(state.db)

scalar(state::ScalarScope, T::DataType) = ScalarScope(state.db, T)

lookup(state::ScalarScope) = Nullable{Query}()

getfinish(state::ScalarScope) = state.finish

setfinish(state::ScalarScope, finish::Query) =
    ScalarScope(state.db, state.dom, Nullable{Query}(finish))


function mkfinish(state::AbstractScope, select::Symbol)
    op = lookup(state, select)
    @assert !isnull(op)
    op = get(op)
    op = finalize(op)
    return op
end

function mkfinish(state::AbstractScope, select::Tuple)
    ops = tuple(map(item -> mkfinish(state, item), select)...)
    I = domain(state)
    O = Tuple{map(op -> datatype(op.output), ops)...}
    input = Iso{I}
    output = Iso{O}
    scope = scalar(state, O)
    pipe = TuplePipe{I,O}([op.pipe for op in ops])
    return Query(input, output, scope, pipe)
end


scope(db::Database) = RootScope(db)

