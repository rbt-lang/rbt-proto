#
# Implementation of scope operations for the toy backend.
#

call(binding::AbstractBinding, base::Scope, args::Vector{AbstractSyntax}) =
    call(binding, base, args...)


immutable SimpleBinding <: AbstractBinding
    query::Query
end

call(binding::SimpleBinding, base::Scope) = binding.query


immutable ParamBinding <: AbstractBinding
    tag::Symbol
    output::Output
end

call(binding::ParamBinding, base::Scope) =
    let scope = nest(base, domain(binding.output)),
        pipe = ParamPipe(domain(base), binding.tag, binding.output)
        Query(scope, pipe)
    end


immutable ClassBinding <: AbstractBinding
    db::ToyDatabase
    classname::Symbol
end

call(binding::ClassBinding, base::Scope) =
    let scope = nest(base, Entity{binding.classname}),
        class = binding.db.schema.name2class[binding.classname],
        set = binding.db.instance.sets[binding.classname],
        pipe = SetPipe(binding.classname, set, ismonic=true, iscovering=true)
        Query(scope, pipe)
    end


immutable ArrowBinding <: AbstractBinding
    db::ToyDatabase
    classname::Symbol
    arrowname::Symbol
end

call(binding::ArrowBinding, base::Scope) =
    let class = binding.db.schema.name2class[binding.classname],
        arrow = class.name2arrow[binding.arrowname],
        scope = nest(base, odomain(arrow)),
        scope = settag(scope, binding.arrowname),
        tag = symbol(binding.classname, "/", binding.arrowname),
        map = binding.db.instance.maps[binding.classname, binding.arrowname],
        pipe = EntityMapPipe(tag, Entity{binding.classname}, map, omode(arrow))
        if arrow.select != nothing
            out = mkselect(scope, arrow.select)
            out = Query(out, scope=settag(out.scope, binding.arrowname))
            scope = addlocal(scope, :__out, out)
        end
        Query(scope, pipe)
    end


immutable EntityIdBinding <: AbstractBinding
    classname::Symbol
end

call(binding::EntityIdBinding, base::Scope) =
    let scope = nest(base, Int),
        pipe = ItemPipe(Entity{binding.classname}, :id, runique=true)
        Query(scope, pipe)
    end


immutable GlobalBinding <: AbstractBinding
    fn::Symbol
end

call(binding::GlobalBinding, base::Scope, args::Vector{AbstractSyntax}) =
    compile(Fn{binding.fn}, base, args...)


scope(db::ToyDatabase) =
    begin
        globals = SymbolTable()
        for m in methods(RBT.compile)
            if length(m.sig.parameters) < 1
                continue
            end
            p = m.sig.parameters[1]
            ps =
                isa(p, Union) ? collect(Type, p.types) :
                p <: Type ? Type[p.parameters[1]] : Type[]
            for p in ps
                if p <: Type
                    p = p.parameters[1]
                end
                if p <: Fn
                    name = fnname(p)
                    if isa(name, Symbol)
                        globals = assoc(globals, (name, -1), GlobalBinding(name))
                    end
                end
            end
        end
        locals = SymbolTable()
        for c in db.schema.classes
            locals = assoc(locals, (c.name, 0), ClassBinding(db, c.name))
        end
        return Scope(db, Unit, globals=globals, locals=locals)
    end


nest(db::ToyDatabase, base::Scope, domain::Type) =
    begin
        tag = NullableSymbol()
        locals = SymbolTable()
        if isentity(domain)
            class = db.schema.name2class[classname(domain)]
            tag = NullableSymbol(class.name)
            locals = assoc(locals, (:id, 0), EntityIdBinding(class.name))
            for arrow in class.arrows
                locals = assoc(locals, (arrow.name, 0), ArrowBinding(db, class.name, arrow.name))
            end
        elseif domain == Unit
            for c in db.schema.classes
                locals = assoc(locals, (c.name, 0), ClassBinding(db, c.name))
            end
        end
        scope = Scope(db, domain, globals=base.globals, locals=locals, tag=tag)
        if isentity(domain)
            scope = addlocal(scope, (:__id, 0), locals[:id, 0])
            if class.select != nothing
                out = mkselect(scope, class.select)
                out = Query(out, scope=settag(out.scope, classname(domain)))
                scope = addlocal(scope, (:__out, 0), out)
            end
            if isa(class.select, Tuple)
                items = tuple([SimpleBinding(mkselect(scope, name, false)) for name in class.select]...)
                scope = setitems(scope, items)
            end
        end
        return scope
    end

mkselect(base::Scope, name::Symbol, finish::Bool=true) =
    let binding = get(lookup(base, (name, 0)))
        finish ? select(binding(base)) : binding(base)
    end

mkselect(base::Scope, names::Tuple, finish::Bool=true) =
    let fields = Query[mkselect(base, name, finish) for name in names]
        pipe = TuplePipe([field.pipe for field in fields])
        scope = nest(base, odomain(pipe))
        scope = setitems(
            scope,
            tuple([SimpleBinding(Query(
                fields[k],
                scope=settag(scope, names[k]),
                pipe=ItemPipe(pipe, k))) for k = eachindex(names)]...))
        Query(scope, pipe)
    end

