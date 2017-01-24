Primitives and combinators
==========================


Identity
--------

The identity primitive maps any value to itself.

    using RBT:
        HereTool,
        run

    t = HereTool(Int64)
    #-> Int64 -> Int64

    run(t, 1:10)
    #-> [1,2,3,4,5,6,7,8,9,10]


Constant
--------

The constant primitive produces the same value on any input.

    using RBT:
        CollectionTool,
        ConstTool,
        NullConstTool,
        run

    t = ConstTool(7)
    #-> Any -> Int64

    run(t, 1:10)
    #-> [7,7,7,7,7,7,7,7,7,7]

The `null` constant produces no value on any input.

    t = NullConstTool()
    #-> Any -> Zero?

    run(t, 1:10)
    #-> [#NULL,#NULL  …  #NULL]

The collection primitive produces a plural constant value.

    t = CollectionTool([2,3,5,7])
    #-> Any -> Int64*

    run(t, 1:10)
    #-> [[2,3,5,7],[2,3,5,7]  …  [2,3,5,7]]


Mappings
--------

Attributes and relationships could be encoded using the mapping primitive.

    using RBT:
        MappingTool,
        Output,
        run

    t = MappingTool(Int, Int, 1:11, 10:10:100)
    #-> Int64 -> Int64

    run(t, [2,3,5,7])
    #-> [20,30,50,70]

Optional and plural attributes could also be represented.

    t = MappingTool(
        Int,
        Output(Int, optional=true),
        [1; 1:11; 11],
        10:10:100)
    #-> Int64 -> Int64?

    run(t, [1,2,3,5,7])
    #-> [#NULL,10,20,40,60]

    t = MappingTool(
        Int,
        Output(Int, plural=true),
        1:2:11,
        10:10:100)
    #-> Int64 -> Int64+

    run(t, [3,5])
    #-> [[50,60],[90,100]]


Composition
-----------

Two queries with compatible input and output could be composed.

    using RBT:
        CollectionTool,
        MappingTool,
        Output,
        run

    t1 = CollectionTool([2,3,5])
    #-> Any -> Int64*

    t2 = MappingTool(Int, Output(Int, plural=true), 1:2:11, 10:10:100)
    #-> Int64 -> Int64+

    t = t1 >> t2
    #-> Any -> Int64*

    run(t, [nothing])
    #-> [[30,40,50,60,90,100]]


Records and fields
------------------

The record constructor generates record values.

    using RBT:
        FieldTool,
        MappingTool,
        Output,
        RecordTool,
        domain,
        output,
        run

    t1 = MappingTool(Int, Int, 1:11, 10:10:100)
    #-> Int64 -> Int64

    t2 = MappingTool(
        Int,
        Output(Int, optional=true),
        [1; 1:11; 11],
        10:10:100)
    #-> Int64 -> Int64?

    t3 = MappingTool(
        Int,
        Output(Int, plural=true),
        1:2:11,
        10:10:100)
    #-> Int64 -> Int64+

    t = RecordTool(t1, t2, t3)
    #-> Int64 -> {Int64, Int64?, Int64+}

    display(run(t, [1,3,5]))
    #=>
    OutputFlow[3 × {Int64, Int64?, Int64+}]:
     (10,#NULL,[10,20])
     (30,20,[50,60])
     (50,40,[90,100])
    =#

Individual fields could be extracted.

    dom = domain(output(t))

    t1 = t >> FieldTool(dom, 1)
    #-> Int64 -> Int64

    run(t1, [1,3,5])
    #-> [10,30,50]

    t2 = t >> FieldTool(dom, 2)
    #-> Int64 -> Int64?

    run(t2, [1,3,5])
    #-> [#NULL,20,40]

    t3 = t >> FieldTool(dom, 3)
    #-> Int64 -> Int64+

    run(t3, [1,3,5])
    #-> [[10,20],[50,60],[90,100]]


The count and exists aggregates
-------------------------------

The count aggregate counts the number of values in a sequence.

    using RBT:
        CountTool,
        ExistsTool,
        MappingTool,
        Output,
        run

    t0 = MappingTool(
        Int,
        Output(Int, optional=true, plural=true),
        [1,1,2,4,7,11],
        1:10)
    #-> Int64 -> Int64*

    run(t0, 1:5)
    #-> [Int64[],[1],[2,3],[4,5,6],[7,8,9,10]]

    t = CountTool(t0)
    #-> Int64 -> Int64

    run(t, 1:5)
    #-> [0,1,2,3,4]

    t = ExistsTool(t0)
    #-> Int64 -> Bool

    run(t, 1:5)
    #-> [false,true,true,true,true]


Scalar functions and operators
------------------------------

Any regular function or operator could be lifted to a query combinator.

    using RBT:
        MappingTool,
        OpTool,
        Output,
        run

    t0 = MappingTool(Int, String, 1:6, ["A","B","C","D","E"])
    #-> Int64 -> String

    t = OpTool(*, String, t0, t0, t0)
    #-> Int64 -> String

    run(t, 1:5)
    #-> ["AAA","BBB","CCC","DDD","EEE"]

It can also be applied to optional or plural queries.

    t1 = MappingTool(Int, Output(String, optional=true), [1,2,2,3,3,4], ["X","Y","Z"])
    #-> Int64 -> String?

    t2 = MappingTool(
        Int,
        Output(String, optional=true, plural=true),
        [1,1,2,4,7,11],
        ["0","1","2","3","4","5","6","7","8","9"])
    #-> Int64 -> String*

    t = OpTool(*, String, t0, t1, t2)
    #-> Int64 -> String*

    display(run(t, 1:5))
    #=>
    OutputFlow[5 × String*]:
     String[]
     String[]
     String["CY1","CY2"]
     String[]
     String["EZ6","EZ7","EZ8","EZ9"]
    =#


Aggregate functions
-------------------

Aggregate combinators transform plural queries to singular queries.

    using RBT:
        AggregateTool,
        MappingTool,
        Output,
        run

    t0 = MappingTool(
        Int,
        Output(Int, optional=true, plural=true),
        [1,1,2,4,7,11],
        1:10)
    #-> Int64 -> Int64*

    run(t0, 1:5)
    #-> [Int64[],[1],[2,3],[4,5,6],[7,8,9,10]]

    t = AggregateTool(minimum, false, t0)
    #-> Int64 -> Int64?

    run(t, 1:5)
    #-> [#NULL,1,2,4,7]

    t = AggregateTool(sum, true, t0)
    #-> Int64 -> Int64

    run(t, 1:5)
    #-> [0,1,5,15,34]


Filtering
---------

The sieve combinator passes data the satisfies a certain condition.

    using RBT:
        CollectionTool,
        HereTool,
        OpTool,
        SieveTool,
        run

    t0 = CollectionTool(1:10)
    #-> Any -> Int64*

    t1 = OpTool(isodd, (Int,), Bool, HereTool(Int))
    #-> Int64 -> Bool

    t = t0 >> SieveTool(t1)
    #-> Any -> Int64*

    run(t, [nothing])
    #-> [[1,3,5,7,9]]


Sorting
-------

The sort combinator sorts the query output.

    using RBT:
        CollectionTool,
        DecorateTool,
        MappingTool,
        Output,
        SortByTool,
        SortTool,
        run

    t0 = CollectionTool([10,1,9,2,8,3,7,4,6,5])
    #-> Any -> Int64*

    t = SortTool(t0)
    #-> Any -> Int64*

    run(t, [nothing])
    #-> [[1,2,3,4,5,6,7,8,9,10]]

    t1 = DecorateTool(t0, rev=true)
    #-> Any -> Int64* [rev=true]

    t = SortTool(t1)
    #-> Any -> Int64* [rev=true]

    run(t, [nothing])
    #-> [[10,9,8,7,6,5,4,3,2,1]]

It is also possible to sort by a key.

    tkey = MappingTool(Int, Int, [k % 7 for k = 10:10:100])
    #-> Int64 -> Int64

    run(tkey, 1:10)
    #-> [3,6,2,5,1,4,0,3,6,2]

    t = SortByTool(t0, tkey)
    #-> Any -> Int64*

    run(t, [nothing])
    #-> [[7,5,10,3,1,8,6,4,9,2]]

The sorting key could be nullable.

    tkey = MappingTool(Int, Output(Int, optional=true), [1,1,2,2,3,3,4,4,5,5,6], [1,2,3,4,5])
    #-> Int64 -> Int64?

    run(tkey, 1:10)
    #-> [#NULL,1,#NULL,2,#NULL,3,#NULL,4,#NULL,5]

    t = SortByTool(t0, DecorateTool(tkey, rev=true, nullrev=true))
    #-> Any -> Int64*

    run(t, [nothing])
    #-> [[10,8,6,4,2,1,9,3,7,5]]


Paginating
----------

The take and skip combinators can be used to paginate the output.

    using RBT:
        ConstTool,
        MappingTool,
        NullConstTool,
        Output,
        SkipTool,
        TakeTool,
        run

    t0 = MappingTool(
        Int,
        Output(Int, optional=true, plural=true),
        [1,1,2,4,7,11],
        1:10)
    #-> Int64 -> Int64*

    run(t0, 1:5)
    #-> [Int64[],[1],[2,3],[4,5,6],[7,8,9,10]]

    t = TakeTool(t0, ConstTool(2))
    #-> Int64 -> Int64*

    run(t, 1:5)
    #-> [Int64[],[1],[2,3],[4,5],[7,8]]

    t = SkipTool(t0, ConstTool(2))

    run(t, 1:5)
    #-> [Int64[],Int64[],Int64[],[6],[9,10]]

    t = TakeTool(t0, ConstTool(-2))

    run(t, 1:5)
    #-> [Int64[],Int64[],Int64[],[4],[7,8]]

    t = SkipTool(t0, ConstTool(-2))

    run(t, 1:5)
    #-> [Int64[],[1],[2,3],[5,6],[9,10]]

    t = TakeTool(t0, NullConstTool())

    run(t, 1:5)
    #-> [Int64[],[1],[2,3],[4,5,6],[7,8,9,10]]


Hierarchical closure
--------------------

The connect combinator calculates a closure of a self-referential query.

    using RBT:
        ConnectTool

    t0 = MappingTool(
        Int,
        Output(Int, optional=true),
        [1,2,3,4,5,5],
        2:5)
    #-> Int64 -> Int64?

    run(t0, 1:5)
    #-> [2,3,4,5,#NULL]

    t = ConnectTool(t0, true)
    #-> Int64 -> Int64+

    run(t, 1:5)
    #-> [[1,2,3,4,5],[2,3,4,5],[3,4,5],[4,5],[5]]

    t = ConnectTool(t0, false)
    #-> Int64 -> Int64*

    run(t, 1:5)
    #-> [[2,3,4,5],[3,4,5],[4,5],[5],Int64[]]

The connect combinator also works with plural relationships.

    t0 = MappingTool(
        Int,
        Output(Int, optional=true, plural=true),
        [1,1,1,1,2,2,4,4,6,7,9,9,12],
        [2,3,2,4,2,3,5,2,6,3,2])
    #-> Int64 -> Int64*

    run(t0, 1:12)
    #-> [Int64[],Int64[],Int64[],[2],Int64[],[3,2],Int64[],[4,2],[3],[5,2],Int64[],[6,3,2]]

    t = ConnectTool(t0, true)
    #-> Int64 -> Int64+

    run(t, 1:12)
    #-> [[1],[2],[3],[4,2],[5],[6,3,2],[7],[8,4,2,2],[9,3],[10,5,2],[11],[12,6,3,2,3,2]]

    t = ConnectTool(t0, false)
    #-> Int64 -> Int64*

    run(t, 1:12)
    #-> [Int64[],Int64[],Int64[],[2],Int64[],[3,2],Int64[],[4,2,2],[3],[5,2],Int64[],[6,3,2,3,2]]


Grouping
--------

The group combinator partitions a sequence into groups.

    using RBT:
        CollectionTool,
        DecorateTool,
        GroupByTool,
        HereTool,
        MappingTool,
        RecordTool,
        RollUpTool,
        UniqueTool,
        Output,
        run

    t0 = CollectionTool([10,1,9,2,8,3,7,4,6,5])
    #-> Any -> Int64*

    run(t0, [nothing])
    #-> [[10,1,9,2,8,3,7,4,6,5]]

    t1 = MappingTool(Int, Int, [k % 3 for k = 1:10])
    #-> Int64 -> Int64

    run(t0 >> RecordTool(HereTool(Int), t1), [nothing])
    #-> [[(10,1),(1,1),(9,0),(2,2),(8,2),(3,0),(7,1),(4,1),(6,0),(5,2)]]

    t = GroupByTool(t0, t1)
    #-> Any -> {Int64+, Int64}*

    run(t, [nothing])
    #-> [[([9,3,6],0),([10,1,7,4],1),([2,8,5],2)]]

    t2 = DecorateTool(
        MappingTool(
            Int,
            Int,
            [k % 2 for k = 1:10]),
        rev=true)
    #-> Int64 -> Int64 [rev=true]

    run(t0 >> RecordTool(HereTool(Int), t2), [nothing])
    #-> [[(10,0),(1,1),(9,1),(2,0),(8,0),(3,1),(7,1),(4,0),(6,0),(5,1)]]

    t = GroupByTool(t0, t1, t2)
    #-> Any -> {Int64+, Int64, Int64 [rev=true]}*

    run(t, [nothing])
    #-> [[([9,3],0,1),([6],0,0),([1,7],1,1),([10,4],1,0),([5],2,1),([2,8],2,0)]]

It is possible to run the group combinator without any keys.

    t = GroupByTool(t0)
    #-> Any -> {Int64+}?

    run(t, [nothing])
    #-> [([10,1,9,2,8,3,7,4,6,5],)]

The key could be nullable.

    t3 = MappingTool(
        Int,
        Output(Int, optional=true),
        [1,1,2,2,3,3,4,4,5,5,6],
        1:5)

    run(t0 >> RecordTool(HereTool(Int), t3), [nothing])
    #-> [[(10,5),(1,#NULL),(9,#NULL),(2,1),(8,4),(3,#NULL),(7,#NULL),(4,2),(6,3),(5,#NULL)]]

    t = GroupByTool(t0, t3)
    #-> Any -> {Int64+, Int64?}*

    run(t, [nothing])
    #-> [[([1,9,3,7,5],#NULL),([2],1),([4],2),([6],3),([8],4),([10],5)]]

The group combinator can also handle empty sequences.

    t0 = MappingTool(
        Int,
        Output(Int, optional=true, plural=true),
        [1,11,16,16],
        [1,2,3,4,5,6,7,8,9,10,5,4,3,2,1])
    #-> Int64 -> Int64*

    run(t0, 1:3)
    #-> [[1,2,3,4,5,6,7,8,9,10],[5,4,3,2,1],Int64[]]

    t = GroupByTool(t0, t1, t2)
    #-> Int64 -> {Int64+, Int64, Int64 [rev=true]}*

    display(run(t, 1:3))
    #=>
    OutputFlow[3 × {Int64+, Int64, Int64 [rev=true]}*]:
     [([3,9],0,1),([6],0,0),([1,7],1,1),([4,10],1,0),([5],2,1),([2,8],2,0)]
     [([3],0,1),([1],1,1),([4],1,0),([5],2,1),([2],2,0)]
     []
    =#

The rollup combinator adds summary rows.

    t = RollUpTool(t0, t1, t2)
    #-> Int64 -> {Int64+, Int64?, Int64? [rev=true]}*

    display(run(t, 1:3))
    #=>
    OutputFlow[3 × {Int64+, Int64?, Int64? [rev=true]}*]:
     [([3,9],0,1),([6],0,0),([3,6,9],0,#NULL)  …  ([5],2,1),([2,8],2,0),([2,5,8],2,#NULL),([1,2,3,4,5,6,7,8,9,10],#NULL,#NULL)]
     [([3],0,1),([3],0,#NULL)  …  ([5],2,1),([2],2,0),([5,2],2,#NULL),([5,4,3,2,1],#NULL,#NULL)]
     []
    =#

The unique combinator filters out duplicate values.

    t0 = MappingTool(
        Int,
        Output(Int, optional=true, plural=true),
        [1,1,2,4,7,11],
        [1,2,1,2,1,2,1,2,1,2])
    #-> Int64 -> Int64*

    run(t0, 1:5)
    #-> [Int64[],[1],[2,1],[2,1,2],[1,2,1,2]]

    t = UniqueTool(t0)
    #-> Int64 -> Int64*

    run(t, 1:5)
    #-> [Int64[],[1],[2,1],[2,1],[1,2]]


Parameters
----------

The parameter primitive extracts a parameter value from the input flow.

    using RBT:
        CollectionTool,
        InputContext,
        InputFlow,
        InputFrame,
        InputParameterFlow,
        MappingTool,
        Output,
        OutputFlow,
        ParameterTool,
        SieveTool,
        run

    t0 = CollectionTool(1:10)
    #-> Any -> Int64*

    t1 = MappingTool(Int, Int, [k % 3 for k = 1:10])
    #-> Int64 -> Int64

    t2 = ParameterTool(:D, Output(Int))
    #-> {Any, D => Int64} -> Int64

    t = t0 >> SieveTool(t1 .== t2)
    #-> {Any, D => Int64} -> Int64*

    iflow = InputFlow(
        InputContext(),
        Void,
        [nothing],
        InputFrame(),
        InputParameterFlow[:D => OutputFlow(Int, [1, 2], [1])])
    #-> [(nothing,:D=>1)]

    run(t, iflow)
    #-> [[1,4,7,10]]

