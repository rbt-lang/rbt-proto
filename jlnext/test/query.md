Query primitives and combinators
================================


Query interface
---------------

A query object is constructed using query primitives and combinators.  For
example, a query that increments its input is constructed as follows.

    using RBT:
        ConstQuery,
        ItQuery,
        LiftQuery

    q = LiftQuery(
            +,
            ItQuery(Int),
            ConstQuery(1))
    #-> Int64 -> Int64

A query can be evaluated on a sequence of input values.

    using RBT:
        ev

    ev(q, 1:5)
    #-> [2,3,4,5,6]


Constants
---------

The constant query produces, on any input, the same output value.

    using RBT:
        ConstQuery

    q = ConstQuery(7)
    #-> Any -> Int64

    ev(q, 1:3)
    #-> [7,7,7]

We can clarify the input and the output type of a constant query.

    q = ConstQuery(Void, :Dept, 7)
    #-> Void -> Dept

    ev(q)
    #-> [Dept(7)]

The `null` constant produces no output.

    using RBT:
        NullQuery

    q = NullQuery()
    #-> Any -> None?

    ev(q, 1:3)
    #-> [#NULL,#NULL,#NULL]


Identity
--------

The identity query maps any value to itself.

    using RBT:
        ItQuery

    q = ItQuery(Int)
    #-> Int64 -> Int64

    ev(q, 1:3)
    #-> [1,2,3]

For any query, we can produce two identity queries: on its input and its output
types.

    using RBT:
        MappingQuery,
        istub,
        ostub

    q = MappingQuery(:Emp, :Dept, 10:10:100)
    #-> Emp -> Dept

    ev(q, 1:3)
    #-> [Dept(10),Dept(20),Dept(30)]

    ql = istub(q)
    #-> Emp -> Emp

    ev(ql, 1:3)
    #-> [Emp(1),Emp(2),Emp(3)]

    qr = ostub(q)
    #-> Dept -> Dept

    ev(qr, 1:3)
    #-> [Dept(1),Dept(2),Dept(3)]


Collections and mappings
------------------------

Static collections of database entities can be specified using the collection
primitive.

    using RBT:
        CollectionQuery

    q = CollectionQuery(:Emp, [2,3,5,7])
    #-> Void -> Emp*

    ev(q)
    #-> [[Emp(2),Emp(3),Emp(5),Emp(7)]]

Attributes and relationships can be encoded using the mapping primitive.

    using RBT:
        MappingQuery

    q = MappingQuery(:Emp, Int, 10:10:100)
    #-> Emp -> Int64

    ev(q, [1,3,5])
    #-> [10,30,50]

Optional and plural values can also be represented.

    q = MappingQuery(:Emp, Int, Nullable{Int}[nothing;10:10:100;nothing])
    #-> Emp -> Int64?

    ev(q, [1,3,5])
    #-> [#NULL,20,40]

    q = MappingQuery(:Emp, Int, [[k,k+10] for k = 10:20:100])
    #-> Emp -> Int64*

    ev(q, [1,3,5])
    #-> [[10,20],[50,60],[90,100]]


Composition
-----------

Queries with compatible input and output could be composed.

    using RBT:
        ComposeQuery

    q1 = CollectionQuery(:Emp, [2,3,5])
    #-> Void -> Emp*

    q2 = MappingQuery(:Emp, :Dept, 0:9)
    #-> Emp -> Dept

    q3 = MappingQuery(:Dept, Int, [[k,k+10] for k = 10:20:100])
    #-> Dept -> Int64*

    q = ComposeQuery([q1, q2, q3])
    #-> Void -> Int64*

    ev(q)
    #-> [[10,20,30,40,70,80]]

The `>>` operator can be used to construct query composition.

    q = q1 >> q2 >> q3
    #-> Void -> Int64*

    ev(q)
    #-> [[10,20,30,40,70,80]]


Records and fields
------------------

The record constructor generates record values.

    using RBT:
        RecordQuery

    q1 = MappingQuery(10:10:100)
    #-> Int64 -> Int64

    q2 = MappingQuery(Nullable{Int}[nothing;10:10:100;nothing])
    #-> Int64 -> Int64?

    q3 = MappingQuery([[k,k+10] for k = 10:20:100])
    #-> Int64 -> Int64*

    q = RecordQuery(q1, q2, q3)
    #-> Int64 -> {Int64, Int64?, Int64*}

    ev(q, [1,3,5])
    #-> [(10,#NULL,[10,20]),(30,20,[50,60]),(50,40,[90,100])]

We could extract individual record fields.

    using RBT:
        FieldQuery,
        output

    q1 = q >> FieldQuery(output(q), 1)
    #-> Int64 -> Int64

    ev(q1, [1,3,5])
    #-> [10,30,50]

    q2 = q >> FieldQuery(output(q), 2)
    #-> Int64 -> Int64?

    ev(q2, [1,3,5])
    #-> [#NULL,20,40]

    q3 = q >> FieldQuery(output(q), 3)
    #-> Int64 -> Int64*

    ev(q3, [1,3,5])
    #-> [[10,20],[50,60],[90,100]]


Scalar functions and operators
------------------------------

Any Julia function or operator could be lifted to a query combinator.

    using RBT:
        LiftQuery

    q0 = MappingQuery(["A","B","C","D","E"])
    #-> Int64 -> String

    q = LiftQuery(*, q0, q0, q0)
    #-> Int64 -> String

    ev(q, 1:5)
    #-> ["AAA","BBB","CCC","DDD","EEE"]

It can also be applied to optional or plural queries.

    q1 = MappingQuery(Nullable{String}["X",nothing,"Y",nothing,"Z"])
    #-> Int64 -> String?

    q2 = MappingQuery(Vector{String}[[],["0"],["1","2"],["3","4","5"],["6","7","8","9"]])
    #-> Int64 -> String*

    q = LiftQuery(*, q0, q1, q2)
    #-> Int64 -> String*

    display(ev(q, 1:5))
    #=>
    OutputFlow[5 × String*]:
     String[]
     String[]
     String["CY1","CY2"]
     String[]
     String["EZ6","EZ7","EZ8","EZ9"]
    =#

Functions that return nullable/vector values can be lifted to optional/plural
combinators.

    q0 = MappingQuery(["A","A B","A B C"])
    #-> Int64 -> String

    q = LiftQuery(split, q0)
    #-> Int64 -> SubString{String}*

    display(ev(q, 1:3))
    #=>
    OutputFlow[3 × SubString{String}*]:
     SubString{String}["A"]
     SubString{String}["A","B"]
     SubString{String}["A","B","C"]
    =#


The count and exists aggregates
-------------------------------

The count aggregate counts the number of values in a sequence.

    using RBT:
        CountQuery

    q0 = MappingQuery(Vector{Int}[[],[1],[2,3],[4,5,6],[7,8,9,10]])
    #-> Int64 -> Int64*

    ev(q0, 1:5)
    #-> [Int64[],[1],[2,3],[4,5,6],[7,8,9,10]]

    q = CountQuery(q0)
    #-> Int64 -> Int64

    ev(q, 1:5)
    #-> [0,1,2,3,4]

The exists aggregate checks if the output contains at least one value.

    using RBT:
        ExistsQuery

    q = ExistsQuery(q0)
    #-> Int64 -> Bool

    ev(q, 1:5)
    #-> [false,true,true,true,true]


Aggregate functions
-------------------

Aggregate combinators transform plural queries to singular queries.

    using RBT:
        AggregateQuery

    q0 = MappingQuery(Vector{Int}[[],[1],[2,3],[4,5,6],[7,8,9,10]])
    #-> Int64 -> Int64*

    ev(q0, 1:5)
    #-> [Int64[],[1],[2,3],[4,5,6],[7,8,9,10]]

    q = AggregateQuery(minimum, Int, Int, false, q0)
    #-> Int64 -> Int64?

    ev(q, 1:5)
    #-> [#NULL,1,2,4,7]

    q = AggregateQuery(sum, Int, Int, q0)
    #-> Int64 -> Int64

    ev(q, 1:5)
    #-> [0,1,5,15,34]


Filtering
---------

The filter combinator removes the data that fails to satisfy a certain
condition.

    using RBT:
        FilterQuery

    q0 = CollectionQuery(:Emp, 1:10)
    #-> Void -> Emp*

    q1 = MappingQuery(:Emp, Int, 1:10)
    #-> Emp -> Int64

    q2 = LiftQuery(isodd, (Int,), Bool, q1)
    #-> Emp -> Bool

    q = FilterQuery(q0, q2)
    #-> Void -> Emp*

    ev(q)
    #-> [[Emp(1),Emp(3),Emp(5),Emp(7),Emp(9)]]


Sorting
-------

The sort combinator sorts the query output.

    using RBT:
        SortQuery,
        decorate

    q0 = CollectionQuery([10,1,9,2,8,3,7,4,6,5])
    #-> Void -> Int64*

    q = SortQuery(q0)
    #-> Void -> Int64*

    ev(q)
    #-> [[1,2,3,4,5,6,7,8,9,10]]

    q = SortQuery(q0 |> decorate(:rev => true))
    #-> Void -> Int64[rev=true]*

    ev(q)
    #-> [[10,9,8,7,6,5,4,3,2,1]]

It is also possible to sort by a key.

    qk = MappingQuery([k % 7 for k = 10:10:100])
    #-> Int64 -> Int64

    ev(q >> RecordQuery(ostub(q), qk))
    #-> [[(10,2),(9,6),(8,3),(7,0),(6,4),(5,1),(4,5),(3,2),(2,6),(1,3)]]

    q = SortQuery(q0, qk)
    #-> Void -> Int64*

    ev(q)
    #-> [[7,5,10,3,1,8,6,4,9,2]]

The sorting key could be nullable.

    qk = MappingQuery(Nullable{Int}[nothing,1,nothing,2,nothing,3,nothing,4,nothing,5])
    #-> Int64 -> Int64?

    ev(q >> RecordQuery(ostub(q), qk))
    #-> [[(7,#NULL),(5,#NULL),(10,5),(3,#NULL),(1,#NULL),(8,4),(6,3),(4,2),(9,#NULL),(2,1)]]

    q = SortQuery(q0, qk)
    #-> Void -> Int64*

    ev(q)
    #-> [[1,9,3,7,5,2,4,6,8,10]]

    q = SortQuery(q0, qk |> decorate(:rev => true) |> decorate(:nullrev => true))
    #-> Void -> Int64*

    ev(q)
    #-> [[10,8,6,4,2,1,9,3,7,5]]


Paginating
----------

The take and skip combinators can be used to paginate the output.

    using RBT:
        TakeQuery,
        SkipQuery

    q0 = MappingQuery(Vector{Int}[[],[1],[2,3],[4,5,6],[7,8,9,10]])
    #-> Int64 -> Int64*

    ev(q0, 1:5)
    #-> [Int64[],[1],[2,3],[4,5,6],[7,8,9,10]]

    q = TakeQuery(q0, ConstQuery(2))
    #-> Int64 -> Int64*

    ev(q, 1:5)
    #-> [Int64[],[1],[2,3],[4,5],[7,8]]

    q = SkipQuery(q0, ConstQuery(2))

    ev(q, 1:5)
    #-> [Int64[],Int64[],Int64[],[6],[9,10]]

    q = TakeQuery(q0, ConstQuery(-2))

    ev(q, 1:5)
    #-> [Int64[],Int64[],Int64[],[4],[7,8]]

    q= SkipQuery(q0, ConstQuery(-2))

    ev(q, 1:5)
    #-> [Int64[],[1],[2,3],[5,6],[9,10]]

    q = TakeQuery(q0, NullQuery())

    ev(q, 1:5)
    #-> [Int64[],[1],[2,3],[4,5,6],[7,8,9,10]]


Hierarchical closure
--------------------

The connect combinator calculates a closure of a self-referential query.

    using RBT:
        ConnectQuery

    q0 = MappingQuery(Nullable{Int}[2,3,4,5,nothing])
    #-> Int64 -> Int64?

    ev(q0, 1:5)
    #-> [2,3,4,5,#NULL]

    q = ConnectQuery(true, q0)
    #-> Int64 -> Int64+

    ev(q, 1:5)
    #-> [[1,2,3,4,5],[2,3,4,5],[3,4,5],[4,5],[5]]

    q = ConnectQuery(false, q0)
    #-> Int64 -> Int64*

    ev(q, 1:5)
    #-> [[2,3,4,5],[3,4,5],[4,5],[5],Int64[]]

The connect combinator also works with plural relationships.

    q0 = MappingQuery(Vector{Int}[[],[],[],[2],[],[3,2],[],[4,2],[3],[5,2],[],[6,3,2]])
    #-> Int64 -> Int64*

    ev(q0, 1:12)
    #-> [Int64[],Int64[],Int64[],[2],Int64[],[3,2],Int64[],[4,2],[3],[5,2],Int64[],[6,3,2]]

    q = ConnectQuery(true, q0)
    #-> Int64 -> Int64+

    ev(q, 1:12)
    #-> [[1],[2],[3],[4,2],[5],[6,3,2],[7],[8,4,2,2],[9,3],[10,5,2],[11],[12,6,3,2,3,2]]

    q = ConnectQuery(false, q0)
    #-> Int64 -> Int64*

    ev(q, 1:12)
    #-> [Int64[],Int64[],Int64[],[2],Int64[],[3,2],Int64[],[4,2,2],[3],[5,2],Int64[],[6,3,2,3,2]]


Grouping
--------

The group combinator partitions a sequence into groups.

    using RBT:
        GroupQuery

    q0 = CollectionQuery([10,1,9,2,8,3,7,4,6,5])
    #-> Void -> Int64*

    ev(q0)
    #-> [[10,1,9,2,8,3,7,4,6,5]]

    q1 = MappingQuery([k % 3 for k = 1:10])
    #-> Int64 -> Int64

    ev(q0 >> RecordQuery(ostub(q0), q1))
    #-> [[(10,1),(1,1),(9,0),(2,2),(8,2),(3,0),(7,1),(4,1),(6,0),(5,2)]]

    q = GroupQuery(q0, q1)
    #-> Void -> {Int64+, Int64}*

    ev(q)
    #-> [[([9,3,6],0),([10,1,7,4],1),([2,8,5],2)]]

    q2 = MappingQuery([k % 2 for k = 1:10]) |> decorate(:rev => true)
    #-> Int64 -> Int64[rev=true]

    ev(q0 >> RecordQuery(ostub(q0), q2))
    #-> [[(10,0),(1,1),(9,1),(2,0),(8,0),(3,1),(7,1),(4,0),(6,0),(5,1)]]

    q = GroupQuery(q0, q1, q2)
    #-> Void -> {Int64+, Int64, Int64[rev=true]}*

    ev(q)
    #-> [[([9,3],0,1),([6],0,0),([1,7],1,1),([10,4],1,0),([5],2,1),([2,8],2,0)]]

It is possible to run the group combinator without any keys.

    q = GroupQuery(q0)
    #-> Void -> {Int64+}?

    ev(q)
    #-> [([10,1,9,2,8,3,7,4,6,5],)]

The key could be nullable.

    q3 = MappingQuery(Nullable{Int}[nothing,1,nothing,2,nothing,3,nothing,4,nothing,5])

    ev(q0 >> RecordQuery(ostub(q0), q3))
    #-> [[(10,5),(1,#NULL),(9,#NULL),(2,1),(8,4),(3,#NULL),(7,#NULL),(4,2),(6,3),(5,#NULL)]]

    q = GroupQuery(q0, q3)
    #-> Void -> {Int64+, Int64?}*

    ev(q)
    #-> [[([1,9,3,7,5],#NULL),([2],1),([4],2),([6],3),([8],4),([10],5)]]

The group combinator can also handle empty sequences.
1
    q0 = MappingQuery(Vector{Int}[[1:10;],[5:-1:1;],[]])
    #-> Int64 -> Int64*

    ev(q0, 1:3)
    #-> [[1,2,3,4,5,6,7,8,9,10],[5,4,3,2,1],Int64[]]

    q = GroupQuery(q0, q1, q2)
    #-> Int64 -> {Int64+, Int64, Int64[rev=true]}*

    display(ev(q, 1:3))
    #=>
    OutputFlow[3 × {Int64+, Int64, Int64[rev=true]}*]:
     [([3,9],0,1),([6],0,0),([1,7],1,1),([4,10],1,0),([5],2,1),([2,8],2,0)]
     [([3],0,1),([1],1,1),([4],1,0),([5],2,1),([2],2,0)]
     []
    =#

The rollup combinator adds summary rows.

    using RBT:
        RollUpQuery

    q = RollUpQuery(q0, q1, q2)
    #-> Int64 -> {Int64+, Int64?, Int64[rev=true]?}*

    display(ev(q, 1:3))
    #=>
    OutputFlow[3 × {Int64+, Int64?, Int64[rev=true]?}*]:
     [([3,9],0,1),([6],0,0),([3,6,9],0,#NULL)  …  ([5],2,1),([2,8],2,0),([2,5,8],2,#NULL),([1,2,3,4,5,6,7,8,9,10],#NULL,#NULL)]
     [([3],0,1),([3],0,#NULL)  …  ([5],2,1),([2],2,0),([5,2],2,#NULL),([5,4,3,2,1],#NULL,#NULL)]
     []
    =#

The unique combinator filters out duplicate values.

    using RBT:
        UniqueQuery

    q0 = MappingQuery(Vector{Int}[[],[1],[2,1],[2,1,2],[1,2,1,2]])
    #-> Int64 -> Int64*

    ev(q0, 1:5)
    #-> [Int64[],[1],[2,1],[2,1,2],[1,2,1,2]]

    q = UniqueQuery(q0)
    #-> Int64 -> Int64*

    ev(q, 1:5)
    #-> [Int64[],[1],[2,1],[2,1],[1,2]]


Slots
-----

The slot primitive extracts a slot value from the input flow.

    using RBT:
        GivenQuery,
        InputContext,
        InputFlow,
        InputFrame,
        InputSlotFlow,
        OutputFlow,
        SlotQuery

    q0 = CollectionQuery(1:10)
    #-> Void -> Int64*

    q1 = LiftQuery(%, ItQuery(Int), ConstQuery(3))
    #-> Int64 -> Int64

    q2 = SlotQuery(:D, Int)
    #-> {Any, D => Int64} -> Int64

    q = FilterQuery(q0, LiftQuery(==, q1, q2))
    #-> {Void, D => Int64} -> Int64*

    iflow = InputFlow(
        InputContext(),
        Void,
        [nothing],
        InputFrame(),
        InputSlotFlow[:D => OutputFlow(Int, [1, 2], [1])])
    #-> [(nothing,:D=>1)]

    ev(q, iflow)
    #-> [[1,4,7,10]]

The value of the slot could be specified with the given combinator.

    q = GivenQuery(q, :D => ConstQuery(1))
    #-> Void -> Int64*

    ev(q)
    #-> [[1,4,7,10]]


Input context
-------------

The combinator `around` relates dataset values to each other.

    using RBT:
        AroundQuery,
        FrameQuery

    iflow = InputFlow(
        InputContext(),
        Int,
        1:10,
        InputFrame([1,2,4,7,11]))

    display(iflow)
    #=>
    InputFlow[10 × (Int64...)]:
     (1,[1])
     (1,[2,3])
     (2,[2,3])
     (1,[4,5,6])
     (2,[4,5,6])
     (3,[4,5,6])
     (1,[7,8,9,10])
     (2,[7,8,9,10])
     (3,[7,8,9,10])
     (4,[7,8,9,10])
    =#

    q0 = AroundQuery(Int, false, true, false)
    #-> (Int64...) -> Int64*

    q = RecordQuery(ItQuery(Int), q0)
    #-> (Int64...) -> {Int64, Int64*}

    display(ev(q, iflow))
    #=>
    OutputFlow[10 × {Int64, Int64*}]:
     (1,Int64[])
     (2,Int64[])
     (3,[2])
     (4,Int64[])
     (5,[4])
     (6,[4,5])
     (7,Int64[])
     (8,[7])
     (9,[7,8])
     (10,[7,8,9])
    =#

    q0 = AroundQuery(Int, true, true, false)
    #-> (Int64...) -> Int64+

    q = RecordQuery(ItQuery(Int), q0)
    #-> (Int64...) -> {Int64, Int64+}

    display(ev(q, iflow))
    #=>
    OutputFlow[10 × {Int64, Int64+}]:
     (1,[1])
     (2,[2])
     (3,[2,3])
     (4,[4])
     (5,[4,5])
     (6,[4,5,6])
     (7,[7])
     (8,[7,8])
     (9,[7,8,9])
     (10,[7,8,9,10])
    =#

    q0 = AroundQuery(Int, true, true, true)
    #-> (Int64...) -> Int64+

    q = RecordQuery(ItQuery(Int), q0)
    #-> (Int64...) -> {Int64, Int64+}

    display(ev(q, iflow))
    #=>
    OutputFlow[10 × {Int64, Int64+}]:
     (1,[1])
     (2,[2,3])
     (3,[2,3])
     (4,[4,5,6])
     (5,[4,5,6])
     (6,[4,5,6])
     (7,[7,8,9,10])
     (8,[7,8,9,10])
     (9,[7,8,9,10])
     (10,[7,8,9,10])
    =#

The set of neighbors could be restricted by the value of a key.

    qkey = LiftQuery(%, ItQuery(Int), ConstQuery(2))
    #-> Int64 -> Int64

    ev(qkey, 1:10)
    #-> [1,0,1,0,1,0,1,0,1,0]

    q0 = AroundQuery(Int, true, true, true, qkey)
    #-> (Int64...) -> Int64+

    q = RecordQuery(ItQuery(Int), q0)
    #-> (Int64...) -> {Int64, Int64+}

    display(ev(q, iflow))
    #=>
    OutputFlow[10 × {Int64, Int64+}]:
     (1,[1])
     (2,[2])
     (3,[3])
     (4,[4,6])
     (5,[5])
     (6,[4,6])
     (7,[7,9])
     (8,[8,10])
     (9,[7,9])
     (10,[8,10])
    =#

It is possible to frame the input context.

    q = FrameQuery(q)
    #-> Int64 -> {Int64, Int64+}

    display(ev(q, 1:10))
    #=>
    OutputFlow[10 × {Int64, Int64+}]:
     (1,[1])
     (2,[2])
     (3,[3])
     (4,[4])
     (5,[5])
     (6,[6])
     (7,[7])
     (8,[8])
     (9,[9])
     (10,[10])
    =#

