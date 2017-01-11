Data containers
===============


Columns
-------

A vector of data values together with a vector of offsets is called a *column*.

    using RBT:
        Column,
        offsets,
        values

In a column-oriented format, all values of an entity attribute are stored in a
single data vector.  However, for an optional attribute, an entity may have no
associated attribute value.  Similarly, for a plural attribute, an entity may
have multiple attribute values.  To support optional and plural attributes, the
data vector is indexed by an associated vector of offsets, which maps an entity
to the respective attribute values.

    iso_col = Column(1:11, 1:10)
    #-> [[1],[2],[3],[4],[5],[6],[7],[8],[9],[10]]

    display(iso_col)
    #=>
    10-element RBT.Column{Int64,UnitRange{Int64},UnitRange{Int64}}:
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

The components of the column could be obtained using functions
`offsets()` and `values()`.

    offsets(iso_col)
    #-> 1:11

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
        InputContext,
        InputFlow,
        InputFrame,
        InputParameterFlow,
        context,
        frameoffsets,
        input,
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
        [InputParameterFlow(:X, OutputFlow(Int64, 1:11, 10:10:100))])
    display(param_flow)
    #=>
    InputFlow[10 × {Int64, X => Int64}]:
     (1,:X=>10)
     (2,:X=>20)
     (3,:X=>30)
     ⋮
     (9,:X=>90)
     (10,:X=>100)
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
    #-> Pair{Symbol,RBT.OutputFlow}[:X=>[10,20,30,40,50,60,70,80,90,100]]


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

