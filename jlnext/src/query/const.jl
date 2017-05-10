#
# Constant primitives.
#

# Singular constant.

ConstQuery(idom, odom, val) =
    Query(
        ConstSig(val),
        Input(convert(Domain, idom)),
        Output(convert(Domain, odom)))

ConstQuery(val) =
    ConstQuery(Any, typeof(val), val)

immutable ConstSig <: AbstractPrimitive
    val
end

ev(sig::ConstSig, ity::Input, oty::Output, iflow::InputFlow) =
    ev_const(sig.val, ity, oty, iflow)

ev_const(val, ::Input, oty::Output, iflow::InputFlow) =
    let len = length(iflow)
        OutputFlow(oty, Column(OneTo(len+1), fill(val, len)))
    end

# Null constant.

NullQuery(idom) =
    Query(
        NullSig(),
        Input(convert(Domain, idom)),
        Output(None) |> setoptional())

NullQuery() = NullQuery(Any)

immutable NullSig <: AbstractPrimitive
end

ev(sig::NullSig, ::Input, oty::Output, iflow::InputFlow) =
    let len = length(iflow)
        OutputFlow(oty, Column(fill(1, len+1), None[]))
    end

