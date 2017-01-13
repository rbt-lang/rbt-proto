Data containers
===============


Columns
-------

A vector of data values together with a vector of offsets is called a *column*.

    using RBT:
        Column,
        OneTo,
        offsets,
        values

In a column-oriented format, all values of an entity attribute are stored in a
single data vector.  However, for an optional attribute, an entity may have no
associated attribute value.  Similarly, for a plural attribute, an entity may
have multiple attribute values.  To support optional and plural attributes, the
data vector is indexed by an associated vector of offsets, which maps an entity
to the respective attribute values.

    iso_col = Column(OneTo(11), 1:10)
    #-> [[1],[2],[3],[4],[5],[6],[7],[8],[9],[10]]

    display(iso_col)
    #=>
    10-element RBT.Column{Int64,Base.OneTo{Int64},UnitRange{Int64}}:
     [1]
     [2]
     [3]
     [4]
     [5]
     [6]
     [7]
     [8]
     [9]
     [10]
    =#

    opt_col = Column([1; 1:11; 11], 1:10)
    #-> [Int64[],[1],[2],[3],[4],[5],[6],[7],[8],[9],[10],Int64[]]

    display(opt_col)
    #=>
    12-element RBT.Column{Int64,Array{Int64,1},UnitRange{Int64}}:
     Int64[]
     [1]
     [2]
     [3]
     [4]
     [5]
     [6]
     [7]
     [8]
     [9]
     [10]
     Int64[]
    =#

    seq_col = Column(1:2:11, 1:10)
    #-> [[1,2],[3,4],[5,6],[7,8],[9,10]]

    display(seq_col)
    #=>
    5-element RBT.Column{Int64,StepRange{Int64,Int64},UnitRange{Int64}}:
     [1,2]
     [3,4]
     [5,6]
     [7,8]
     [9,10]
    =#

Columns could also be constructed out of a single vector of data.

    Column([2,3,5])
    #-> [[2],[3],[5]]

    Column([Nullable{Int}(), Nullable(2), Nullable(3), Nullable{Int}(), Nullable(5)])
    #-> [Int64[],[2],[3],Int64[],[5]]

    Column([Int[], [2], [3,5]])
    #-> [Int64[],[2],[3,5]]

Columns could be reordered.

    display(iso_col[[1,3,5]])
    #=>
    3-element RBT.Column{Int64,Base.OneTo{Int64},Array{Int64,1}}:
     [1]
     [3]
     [5]
    =#

    display(opt_col[[1,3,5]])
    #=>
    3-element RBT.Column{Int64,Array{Int64,1},Array{Int64,1}}:
     Int64[]
     [2]
     [4]
    =#

    display(seq_col[[1,3,5]])
    #=>
    3-element RBT.Column{Int64,Array{Int64,1},Array{Int64,1}}:
     [1,2]
     [5,6]
     [9,10]
    =#

The components of the column could be obtained using functions
`offsets()` and `values()`.

    offsets(iso_col)
    #-> Base.OneTo(11)

    values(opt_col)
    #-> 1:10


Output flow
-----------

The query output is represented as an *output flow*.

    using RBT:
        Column,
        Output,
        OutputFlow,
        column,
        domain,
        mode,
        offsets,
        output,
        values

The query output is specified by the output signature, a vector of offsets and
a vector of values.

    int_flow = OutputFlow(Int64, Column(1:101, 1:100))
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
        Output(Int64, optional=true),
        Column([1; 1:101; 101], 1:100))
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
        Output(Int64, plural=true),
        Column(1:50:2001, 1:2000))
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
        InputParameter,
        InputParameterFlow,
        context,
        distribute,
        frameoffsets,
        input,
        narrow,
        parameterflows,
        values

When the input is not position-sensitive and has no parameters, it is specified
with the query context, the input domain and a vector of input values.

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

Similarly, when the query input has non-trivial parameter environment, we need
to specify the values of the parameters.

    param_flow = InputFlow(
        ctx,
        Int64,
        1:10,
        [
            InputParameterFlow(:X, OutputFlow(Int64, 1:11, 10:10:100)),
            InputParameterFlow(:Y, OutputFlow(Int64, 1:11, 100:100:1000)),
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

    parameterflows(param_flow)
    #-> Pair{Symbol,RBT.OutputFlow}[:X=>[10  …  100],:Y=>[100  …  1000]]

The input flow could be narrowed to a smaller input signature.

    nrel_flow = narrow(rel_flow, Input(Int64, relative=false))
    display(nrel_flow)
    #=>
    InputFlow[10 × Int64]:
      1
      2
      ⋮
     10
    =#

    nparam_flow = narrow(param_flow, Input(Int64, parameters=(InputParameter(:X, Int64),)))
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
        [InputParameterFlow(:X, OutputFlow(Int64, 1:11, 10:10:100))])
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
        Output(Int64, optional=true, plural=true),
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


Datasets
--------

An array of records, where the values of each field are stored in separate
columns, is called a *dataset*.

    using RBT:
        Column,
        DataSet,
        Output,
        OutputFlow,
        domain

`DataSet` objects are specified by their length and an array of columns.

    ds = DataSet(
        OutputFlow(Int64, 1:11, 1:10),
        OutputFlow(Output(Int64, optional=true), [1; 1:9; 9], 2:9),
        OutputFlow(Output(Int64, plural=true), 1:5:51, 1:50))
    #-> [(1,#NULL,[1,2,3,4,5]),(2,2,[6,7,8,9,10])  …  (10,#NULL,[46,47,48,49,50])]

    display(ds)
    #=>
    DataSet[10 × {Int64, Int64?, Int64+}]:
     (1,#NULL,[1,2,3,4,5])
     (2,2,[6,7,8,9,10])
     ⋮
     (10,#NULL,[46,47,48,49,50])
    =#

    length(ds)
    #-> 10

    domain(ds)
    #-> {Int64, Int64?, Int64+}

Datasets could be nested.

    tree_ds = DataSet(
        OutputFlow(Int64, 1:3, 1:2),
        OutputFlow(
            Output(domain(ds), plural=true),
            1:5:11,
            ds))
    display(tree_ds)
    #=>
    DataSet[2 × {Int64, {Int64, Int64?, Int64+}+}]:
     (1,[(1,#NULL,[1,2,3,4,5]),(2,2,[6,7,8,9,10])  …  (5,5,[21,22,23,24,25])])
     (2,[(6,6,[26,27,28,29,30]),(7,7,[31,32,33,34,35])  …  (10,#NULL,[46,47,48,49,50])])
    =#

Datasets could be rearranged.

    display(tree_ds[[2,1,2,1]])
    #=>
    DataSet[4 × {Int64, {Int64, Int64?, Int64+}+}]:
     (2,[(6,6,[26,27,28,29,30]),(7,7,[31,32,33,34,35])  …  (10,#NULL,[46,47,48,49,50])])
     (1,[(1,#NULL,[1,2,3,4,5]),(2,2,[6,7,8,9,10])  …  (5,5,[21,22,23,24,25])])
     (2,[(6,6,[26,27,28,29,30]),(7,7,[31,32,33,34,35])  …  (10,#NULL,[46,47,48,49,50])])
     (1,[(1,#NULL,[1,2,3,4,5]),(2,2,[6,7,8,9,10])  …  (5,5,[21,22,23,24,25])])
    =#

