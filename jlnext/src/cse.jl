
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
        if !fits(domain(output(prq)), domain(input(q)))
            for n in gr.nodes
                println(n.self, " ## ", typeof(n.q.sig), " ", n.q, " ", n.args, " pred=", n.pred)
            end
            println("self = $self, tail = $tail")
            println("q = $(q.sig) $q")
            println("prq = $(prq.sig) $prq")
        end
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
    args = Query[ev2query(gr, refs, arg, n.pred) for arg in n.args]
    return RecordQuery(args)
end

