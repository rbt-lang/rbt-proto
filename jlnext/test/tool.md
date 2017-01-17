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


The count aggregate
-------------------

The count aggregate counts the number of values in a sequence.

    using RBT:
        CountTool
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

