Data containers
===============


Records
-------

A record is an immutable composite type with named fields.

    using RBT:
        @Record,
        recordtype

The `@Record` constructor creates an anonymous record type with the given list
of fields.

    R = @Record(a, b, c)
    #-> @Record(a, b, c)

    r = R(1, 2, 3)
    #-> @Record(a = 1, b = 2, c = 3)

We can also create a new record object in one step.

    @Record(a = 1, b = 2, c = 3)
    #-> @Record(a = 1, b = 2, c = 3)

When creating a record type, the type of the fields can be explicitly declared.

    R2 = @Record(a::Int, b::Nullable{Int}, c::Vector{Int})
    #-> @Record(a::Int64, b::Nullable{Int64}, c::Array{Int64,1})

    r2 = R2(1, 2, 3:10)
    #-> @Record(a = 1, b = Nullable{Int64}(2), c = [3,4,5,6,7,8,9,10])

Again, this could be done in one step.

    @Record(a::Int = 1, b::Nullable{Int} = 2, c::Vector{Int} = 3:10)
    #-> @Record(a = 1, b = Nullable{Int64}(2), c = [3,4,5,6,7,8,9,10])

Finally, a new record type can be created without using a macro.

    recordtype([:a, :b, :c])
    #-> @Record(a, b, c)


Entity classes
--------------

Entity classes represent abstract concepts such as *departments* or
*employees*.  They are distinguished by their *class name* and their identities
are encoded by integer values.

    using RBT:
        Entity,
        classname

    Emp = Entity{:Emp}
    #-> Emp

    e = Emp(1)
    #-> Emp(1)

    classname(Emp)
    #-> :Emp

    classname(e)
    #-> :Emp

    get(e)
    #-> 1


Columns
-------

A vector of data values together with a vector of offsets is called a *column*.

    using RBT:
        Column,
        OptionalColumn,
        PlainColumn,
        PluralColumn,
        OneTo,
        cursor,
        isoptional,
        isplural,
        next!,
        offsets,
        values

In a column-oriented format, all values of an entity attribute are stored in a
single data vector.  However, for an optional attribute, an entity may have no
associated attribute value.  Similarly, for a plural attribute, an entity may
have multiple attribute values.  To support optional and plural attributes, the
data vector is indexed by an associated vector of offsets, which maps an entity
index to the respective attribute values.

    iso_col = PlainColumn(OneTo(11), 1:10)
    #-> [[1],[2],[3],[4],[5],[6],[7],[8],[9],[10]]

    opt_col = OptionalColumn([1; 1:11; 11], 1:10)
    #-> [[],[1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[]]

    seq_col = PluralColumn(1:2:11, 1:10)
    #-> [[1,2],[3,4],[5,6],[7,8],[9,10]]

Columns could also be constructed out of a single vector of data.

    Column([2,3,5])
    #-> [[2],[3],[5]]

    Column(Nullable{Int}[nothing, 2, 3, nothing, 5])
    #-> [[],[2],[3],[],[5]]

    Column([Int[], [2], [3,5]])
    #-> [[],[2],[3,5]]

Columns could be reordered.

    display(iso_col[[1,3,5]])
    #=>
    3-element column of Int64:
     [1]
     [3]
     [5]
    =#

    display(opt_col[[1,3,5]])
    #=>
    3-element column of Int64?:
     []
     [2]
     [4]
    =#

    display(seq_col[[1,3,5]])
    #=>
    3-element column of Int64*:
     [1,2]
     [5,6]
     [9,10]
    =#

A column cursor could be used to iterate over column elements.

    cr = cursor(seq_col)
    #-> []

    while !done(seq_col, cr)
        next!(seq_col, cr)
        println(cr)
    end
    #=>
    [1,2]
    [3,4]
    [5,6]
    [7,8]
    [9,10]
    =#

The components of the column could be obtained using functions `offsets()` and
`values()`.

    offsets(iso_col)
    #-> Base.OneTo(11)

    values(opt_col)
    #-> 1:10

Cardinality of the column could be determined using functions `isoptional()`
and `isplural()`.

    isoptional(iso_col)
    #-> false

    isoptional(opt_col)
    #-> true

    isplural(opt_col)
    #-> false

    isplural(seq_col)
    #-> true


Data vector
-----------

A data vector is a vector of composite data stored in a column-oriented format.

    using RBT:
        DataVector,
        RecordVector,
        TupleVector,
        getdata

    tv0 = TupleVector('a':'e', 1:5)
    #-> [('a',1),('b',2),('c',3),('d',4),('e',5)]

    eltype(tv0)
    #-> Tuple{Char,Int64}

The vector may contain nullable and plural columns.

    tv = TupleVector(1:5, Nullable{Int}[1,2,3,4,nothing], Vector{Int}[[],[1],[2,3],[4,5,6,7],[8,9,10,11,12]])

    eltype(tv)
    #-> Tuple{Int64,Nullable{Int64},SubArray{Int64,1,Array{Int64,1},Tuple{UnitRange{Int64}},true}}

    display(tv)
    #=>
    5-element composite vector of {Int64, Int64?, Int64*}:
     (1,1,Int64[])
     (2,2,[1])
     (3,3,[2,3])
     (4,4,[4,5,6,7])
     (5,#NULL,[8,9,10,11,12])
    =#

Moreover, record vectors could be nested in order to represent hierarchical
output.

    hcol = Column([1,1,3,6], tv)

    display(hcol)
    #=>
    3-element column of {Int64, Int64?, Int64*}*:
     []
     [(1,1,Int64[]),(2,2,[1])]
     [(3,3,[2,3]),(4,4,[4,5,6,7]),(5,#NULL,[8,9,10,11,12])]
    =#

    htv = TupleVector('a':'c', hcol)

    display(htv)
    #=>
    3-element composite vector of {Char, {Int64, Int64?, Int64*}*}:
     ('a',[])
     ('b',[(1,1,Int64[]),(2,2,[1])])
     ('c',[(3,3,[2,3]),(4,4,[4,5,6,7]),(5,#NULL,[8,9,10,11,12])])
    =#

The length of the vector can be explicitly specified.

    TupleVector(5, ())
    #-> [(),(),(),(),()]

It is also possible to create a record vector with named fields.

    rv = RecordVector(ch='a':'e', x=1:5)

    display(rv)
    #=>
    5-element composite vector of {ch::Char, x::Int64}:
     @Record(ch = 'a', x = 1)
     @Record(ch = 'b', x = 2)
     @Record(ch = 'c', x = 3)
     @Record(ch = 'd', x = 4)
     @Record(ch = 'e', x = 5)
    =#

    eltype(rv)
    #-> @Record(ch::Char, x::Int64)

By default, the record vector exposes the type of the columns in its signature.
We can also use a record type that conceals the types of its columns.

    dv = DataVector(1:5, Nullable{Int}[1,2,3,4,nothing], Vector{Int}[[],[1],[2,3],[4,5,6,7],[8,9,10,11,12]])

    display(dv)
    #=>
    5-element composite vector of {Int64, Int64?, Int64*}:
     (1,1,Int64[])
     (2,2,[1])
     (3,3,[2,3])
     (4,4,[4,5,6,7])
     (5,#NULL,[8,9,10,11,12])
    =#

It is possible to convert it to a regular record vector.

    typeof(dv)
    #-> RBT.DataVector

    typeof(convert(TupleVector, dv))
    #-> RBT.TupleVector{Tuple{Int64  …  },Tuple{RBT.Column{false,false,Base.OneTo{Int64},UnitRange{Int64}}  …  }}

