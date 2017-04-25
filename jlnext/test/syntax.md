Syntax tree
===========

We can parse any Julia expression as a Rabbit query.

    using RBT:
        Syntax,
        label,
        value

    s = Syntax(:( department.name ))
    #-> department.name

The result is a syntax tree of the parsed query.  Each brach node in the tree
has a label and a list of child nodes.

    label(s)
    #-> :.

    length(s)
    #-> 2

    foreach(println, s)
    #=>
    department
    name
    =#

Identifiers are represented as branch nodes with no children.

    s = Syntax(:( department ))
    #-> department

    label(s)
    #-> :department

    length(s)
    #-> 0

Literal values are represented as leaf nodes.

    s = Syntax(:( 42 ))
    #-> 42

    value(s)
    #-> 42

Query combinators are translated to branch nodes with arguments represented
child nodes.

    s = Syntax(:( max(department.count(employee)) ))
    #-> max(department.count(employee))

    label(s)
    #-> :max

    foreach(println, s)
    #=>
    department.(count(employee))
    =#

Arithmetic expressions are parsed in a similar matter.

    s = Syntax(:( (3+4)*6 ))
    #-> (3 + 4) * 6

    label(s)
    #-> :*

    foreach(println, s)
    #=>
    3 + 4
    6
    =#

Combinators could also be written in pipeline notation, with the first argument
in front of the combinator.

    s = Syntax(:( department:filter(count(employee) > 1000):count ))
    #-> department:filter(count(employee) > 1000):count

    label(s)
    #-> :count

    foreach(println, s)
    #=>
    department:filter(count(employee) > 1000)
    =#

    foreach(t -> println(label(t), " : ", join(t, ", ")), s)
    #=>
    filter : department, count(employee) > 1000
    =#

