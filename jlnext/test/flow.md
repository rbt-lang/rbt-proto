Input and output data
=====================


Output flow
-----------

The query output is represented as an *output flow*.

    using RBT:
        NonEmptyPluralColumn,
        OptionalColumn,
        Output,
        OutputFlow,
        PlainColumn,
        column,
        domain,
        mode,
        offsets,
        output,
        setoptional,
        setplural,
        values

The query output is specified by the output signature, a vector of offsets and
a vector of values.

    int_flow = OutputFlow(Int64, PlainColumn(1:100))
    #-> [1,2,3  …  99,100]

    display(int_flow)
    #=>
    OutputFlow[100 × Int64]:
       1
       2
       3
       ⋮
      99
     100
    =#

    int_opt_flow = OutputFlow(
        Output(Int64) |> setoptional(),
        OptionalColumn([1; 1:101; 101], 1:100))
    #-> [#NULL,1,2,3  …  99,100,#NULL]

    display(int_opt_flow)
    #=>
    OutputFlow[102 × Int64?]:
     #NULL
     1
     2
     3
     ⋮
     99
     100
     #NULL
    =#

    int_seq_flow = OutputFlow(
        Output(Int64) |> setplural(),
        NonEmptyPluralColumn(1:50:2001, 1:2000))
    display(int_seq_flow)
    #=>
    OutputFlow[40 × Int64+]:
     [1,2,3  …  49,50]
     [51,52,53  …  99,100]
     [101,102,103  …  149,150]
     ⋮
     [1901,1902,1903  …  1949,1950]
     [1951,1952,1953  …  1999,2000]
    =#

The query output could be deconstructed.

    output(int_opt_flow)
    #-> Int64?

    domain(int_opt_flow)
    #-> Int64

    mode(int_opt_flow)
    #-> RBT.OutputMode(true,false)

    column(int_seq_flow)
    #-> [[1,2  …  50],[51,52  …  100]  …  [1951,1952  …  2000]]

    offsets(int_seq_flow)
    #-> 1:50:2001

    values(int_seq_flow)
    #-> 1:2000


Input flow
----------

The query input is represented as an *input flow*.

    using RBT:
        Input,
        InputContext,
        InputFlow,
        InputFrame,
        InputSlot,
        InputSlotFlow,
        context,
        distribute,
        frameoffsets,
        input,
        narrow,
        slotflows,
        setoptional,
        setslots,
        setplural,
        setrelative,
        values

When the input is not position-sensitive and has no slots, it is specified with
the query context, the input domain and a vector of input values.

    ctx = InputContext()

    flow = InputFlow(ctx, Int64, 1:10)
    #-> [1,2,3,4,5,6,7,8,9,10]

    display(flow)
    #=>
    InputFlow[10 × Int64]:
      1
      2
      3
      ⋮
      9
     10
    =#

When the query is aware of the input relative position, we need to specify the
input frame.

    rel_flow = InputFlow(ctx, Int64, 1:10, InputFrame(1:2:11))
    display(rel_flow)
    #=>
    InputFlow[10 × (Int64...)]:
     (1,[1,2])
     (2,[1,2])
     (1,[3,4])
     (2,[3,4])
     ⋮
     (1,[9,10])
     (2,[9,10])
    =#

Similarly, when the query input has non-trivial environment, we need to specify
the values of the slots.

    param_flow = InputFlow(
        ctx,
        Int64,
        1:10,
        [
            InputSlotFlow(:X, OutputFlow(Int64, 10:10:100)),
            InputSlotFlow(:Y, OutputFlow(Int64, 100:100:1000)),
        ])
    display(param_flow)
    #=>
    InputFlow[10 × {Int64, X => Int64, Y => Int64}]:
     (1,:X=>10,:Y=>100)
     (2,:X=>20,:Y=>200)
     (3,:X=>30,:Y=>300)
     ⋮
     (9,:X=>90,:Y=>900)
     (10,:X=>100,:Y=>1000)
    =#

We can easily extract individual components of the input flow.

    context(flow)
    #-> Dict{Symbol,Any}()

    input(flow)
    #-> Int64

    values(flow)
    #-> 1:10

    frameoffsets(rel_flow)
    #-> 1:2:11

    slotflows(param_flow)
    #-> Pair{Symbol,RBT.OutputFlow}[:X=>[10  …  100],:Y=>[100  …  1000]]

The input flow could be narrowed to a smaller input signature.

    nrel_flow = narrow(rel_flow, Input(Int64) |> setrelative(false))
    display(nrel_flow)
    #=>
    InputFlow[10 × Int64]:
      1
      2
      ⋮
     10
    =#

    nparam_flow = narrow(param_flow, Input(Int64) |> setslots([InputSlot(:X, Int64)]))
    display(nparam_flow)
    #=>
    InputFlow[10 × {Int64, X => Int64}]:
     (1,:X=>10)
     (2,:X=>20)
     ⋮
     (10,:X=>100)
    =#

Given an input flow and the corresponding output flow, we can form a new input
flow.

    iflow = InputFlow(
        ctx,
        Int64,
        1:10,
        InputFrame(1:2:11),
        [InputSlotFlow(:X, OutputFlow(Int64, 10:10:100))])
    display(iflow)
    #=>
    InputFlow[10 × {(Int64...), X => Int64}]:
     ((1,[1,2]),:X=>10)
     ((2,[1,2]),:X=>20)
     ((1,[3,4]),:X=>30)
     ((2,[3,4]),:X=>40)
     ((1,[5,6]),:X=>50)
     ((2,[5,6]),:X=>60)
     ((1,[7,8]),:X=>70)
     ((2,[7,8]),:X=>80)
     ((1,[9,10]),:X=>90)
     ((2,[9,10]),:X=>100)
    =#

    oflow = OutputFlow(
        Output(Int64) |> setoptional() |> setplural(),
        [1,1,1,2,2,3,4,6,9,11,11],
        -1:-1:-10)
    display(oflow)
    #=>
    OutputFlow[10 × Int64*]:
     Int64[]
     Int64[]
     [-1]
     Int64[]
     [-2]
     [-3]
     [-4,-5]
     [-6,-7,-8]
     [-9,-10]
     Int64[]
    =#

    display(distribute(iflow, oflow))
    #=>
    InputFlow[10 × {(Int64...), X => Int64}]:
     ((1,[-1]),:X=>30)
     ((1,[-2,-3]),:X=>50)
     ((2,[-2,-3]),:X=>60)
     ((1,[-4,-5,-6,-7,-8]),:X=>70)
     ((2,[-4,-5,-6,-7,-8]),:X=>70)
     ((3,[-4,-5,-6,-7,-8]),:X=>80)
     ((4,[-4,-5,-6,-7,-8]),:X=>80)
     ((5,[-4,-5,-6,-7,-8]),:X=>80)
     ((1,[-9,-10]),:X=>90)
     ((2,[-9,-10]),:X=>90)
    =#

