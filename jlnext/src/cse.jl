
function cse(q::Query)
    gr = query2ev(q)
    q′ = ev2query(gr)
    q′
end

immutable EvNode
    q::Query
    hc::UInt
    self::Int
    pred::Int
    args::Vector{Int}
end

const NO_EV_ARGS = Int[]

immutable EvGraph
    q::Query
    nodes::Vector{EvNode}
    hc2idxs::Dict{UInt,Vector{Int}}
end

function query2ev(q::Query)
    gr = EvGraph(q, EvNode[], Dict{UInt64,Vector{Int}}())
    query2ev!(gr, q, 0)
    gr
end

function query2ev!(gr::EvGraph, q::Query, pred::Int)
    if isa(q.sig, ItSig) && domain(input(q)) == domain(output(q))
        return pred
    end
    if isa(q.sig, ComposeSig)
        self = pred
        for arg in q.args
            self = query2ev!(gr, arg, self)
        end
        return self
    end
    args =
        if !isempty(q.args)
            Int[query2ev!(gr, arg, pred) for arg in q.args]
        else
            NO_EV_ARGS
        end
    hc = hash((q.sig, pred, args))
    if hc in keys(gr.hc2idxs)
        for idx in gr.hc2idxs[hc]
            n = gr.nodes[idx]
            if n.q.sig == q.sig && n.pred == pred
                return idx
            end
        end
    else
        gr.hc2idxs[hc] = Int[]
    end
    self = length(gr.nodes) + 1
    n = EvNode(q, hc, self, pred, args)
    push!(gr.nodes, n)
    push!(gr.hc2idxs[hc], self)
    self
end

ev2query(gr::EvGraph) =
    ev2query(gr, Dict{Tuple{Int,Int},Query}(), length(gr.nodes), 0)

function ev2query(gr::EvGraph, refs::Dict{Tuple{Int,Int},Query}, self::Int, tail::Int)
    if self == 0
        @assert tail == 0
        dom = domain(input(gr.q))
        return ItQuery(dom)
    end
    n = gr.nodes[self]
    if self == tail
        dom = domain(output(n.q))
        return ItQuery(dom)
    end
    if (self, tail) in keys(refs)
        return refs[(self, tail)]
    end
    q = ev2query(gr, refs, n, n.q.sig)
    if n.pred != tail
        prq = ev2query(gr, refs, n.pred, tail)
        q = prq >> q
    end
    q
end

ev2query(gr::EvGraph, refs::Dict{Tuple{Int,Int},Query}, n::EvNode, ::AbstractPrimitive) =
    n.q

function ev2query(gr::EvGraph, refs::Dict{Tuple{Int,Int},Query}, n::EvNode, sig::ConnectSig)
    args = Query[ev2query(gr, refs, arg, n.pred) for arg in n.args]
    return ConnectQuery(sig.refl, args...)
end

function ev2query(gr::EvGraph, refs::Dict{Tuple{Int,Int},Query}, n::EvNode, ::FrameSig)
    args = Query[ev2query(gr, refs, arg, n.pred) for arg in n.args]
    return FrameQuery(args...)
end

function ev2query(gr::EvGraph, refs::Dict{Tuple{Int,Int},Query}, n::EvNode, ::GivenSig)
    args = Query[ev2query(gr, refs, arg, n.pred) for arg in n.args]
    return GivenQuery(args...)
end

function ev2query(gr::EvGraph, refs::Dict{Tuple{Int,Int},Query}, n::EvNode, ::RecordSig)
    dups = finddups(gr, refs, n.args, n.pred)
    if isempty(dups)
        args = Query[ev2query(gr, refs, arg, n.pred) for arg in n.args]
        return RecordQuery(args)
    end
    dupqs = Vector{Query}(length(dups))
    for i = endof(dups):-1:1
        tag = gensym()
        dup = dups[i]
        dupq = ev2query(gr, refs, dup, n.pred) |> decorate(:tag => tag)
        dupqs[i] = dupq
        ref = SlotQuery(tag, output(dupq))
        refs[(dup, n.pred)] = ref
    end
    args = Query[ev2query(gr, refs, arg, n.pred) for arg in n.args]
    q = RecordQuery(args)
    for i = 1:endof(dups)
        dup = dups[i]
        dupq = dupqs[i]
        delete!(refs, (dup, n.pred))
        q = GivenQuery(q, dupq)
    end
    q
end

function finddups(gr::EvGraph, refs::Dict{Tuple{Int,Int},Query}, fs::Vector{Int}, pred::Int)
    if length(fs) <= 1
        return NO_EV_ARGS
    end
    f2k = Dict{Int,Int}()
    stack = Int[]
    for (k, f) in enumerate(fs)
        push!(stack, f)
        while !isempty(stack)
            self = pop!(stack)
            if self == pred || ((self, pred) in keys(refs))
                continue
            end
            if !(self in keys(f2k))
                n = gr.nodes[self]
                if !cheap(n.q.sig)
                    f2k[self] = k
                end
                push!(stack, n.pred)
                if isa(n.q.sig, RecordSig) && n.pred == pred
                    for arg in n.args
                        push!(stack, arg)
                    end
                end
            elseif f2k[self] != k
                f2k[self] = 0
            end
        end
    end
    dups = Int[]
    for (self, k) in f2k
        if k == 0
            push!(dups, self)
        end
    end
    if length(dups) > 1
        dups1 = dups
        dups2 = finddups(gr, refs, dups, pred)
        dups2set = Set(dups2)
        dups = Int[]
        for dup in dups1
            if !(dup in dups2set)
                push!(dups, dup)
            end
        end
        for dup in dups2
            push!(dups, dup)
        end
    end
    dups
end

cheap(sig::AbstractSignature) =
    isa(sig, ConstSig) ||
    isa(sig, NullSig) ||
    isa(sig, ItSig)

