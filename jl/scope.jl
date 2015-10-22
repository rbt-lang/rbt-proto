
immutable RootScope <: AbstractScope
    db::Database
end

show(io::IO, ::RootScope) = print(io, "ROOT")

domain(::RootScope) = Tuple{}

root(state::RootScope) = scope

scalar(state::RootScope, T::DataType) = ScalarScope(state.db, T)

function lookup(state::RootScope, name::Symbol)
    if name in keys(state.db.schema.classes)
        I = domain(state)
        O = Entity{name}
        input = Iso{I}
        output = Seq{O}
        scope = ClassScope(state.db, name)
        pipe = SetPipe{I, O}(name, state.db.instance.sets[name])
        return Nullable{Query}(Query(input, output, scope, pipe))
    else
        return Nullable{Query}()
    end
end


immutable ClassScope <: AbstractScope
    db::Database
    name::Symbol
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
            scope = ClassScope(state.db, classname(O))
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


immutable ScalarScope <: AbstractScope
    db::Database
    dom::DataType
end

show(io::IO, state::ScalarScope) = print(io, "Scalar(", state.dom, ")")

domain(state::ScalarScope) = state.dom

root(state::ScalarScope) = RootScope(state.db)

scalar(state::ScalarScope, T::DataType) = ScalarScope(state.db, T)

lookup(state::ScalarScope) = Nullable{Query}()


scope(db::Database) = RootScope(db)

