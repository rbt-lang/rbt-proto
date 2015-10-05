Querying Hierarchical Data
==========================


Hierarchical data model
-----------------------


.. slide:: Hierarchical Data Model
   :level: 2

    Data is organized in a tree structure.

    .. graphviz:: citydb-hierarchical-model.dot


.. slide:: Hierarchical Data Model: JSON
   :level: 3

    JSON is a way to store hierarchical data.

    .. code-block:: json

        {
            "departments": [
                {
                    "name": "WATER MGMNT",
                    "employees": [
                        {
                            "name": "ALVA",
                            "surname": "A",
                            "position": "WATER RATE TAKER",
                            "salary": 87228
                        },
                        ... ]
                },
                ... ]
        }


.. slide:: Hierarchical Data Model: Asking Questions
   :level: 3

    Example: *For each department, find the number of employees with the salary
    higher that $100k.*

    Can use a programming language, e.g. Julia:

    .. code-block:: julia

        Depts_With_Num_Well_Paid_Empls(data) =
            map(d -> Dict(
                    "name" => d["name"],
                    "N100k" =>
                        length(filter(e -> e["salary"] > 100000, d["employees"]))),
                data["departments"])

    .. code-block:: jlcon

        julia> Depts_With_Num_Well_Paid_Empls(citydb)
        35-element Array{Any,1}:
         Dict("name"=>"WATER MGMNT","N100k"=>179)
         Dict("name"=>"POLICE","N100k"=>1493)
         ⋮


.. slide:: Hierarchical Data Model: Asking Questions 2
   :level: 3

    *For each department, find the number of employees with the salary > $100k.*

    .. code-block:: julia

        Depts_With_Num_Well_Paid_Empls(data) =
            map(d -> Dict(
                    "name" => d["name"],
                    "N100k" =>
                        length(filter(e -> e["salary"] > 100000, d["employees"]))),
                data["departments"])

    Not too bad, but can we do better?

    In particular, can we eliminate anonymous functions?


.. slide:: Hierarchical Data Model: Query Language
   :level: 3

    We will build a "query language" for JSON "databases".

    In 50 lines of Julia code:

    * *Traverse the hierarchy.*
    * *Summarize data.*
    * *Construct new data.*
    * *Filter data.*

    Will help to motivate semantics of **Rabbit**.


Combinators
-----------


.. slide:: Combinators
   :level: 2

    *A JSON combinator* is a function that maps JSON input to JSON output.

    Example: *constant* combinator.

    .. code-block:: julia

        Const(val) = x -> val

    .. code-block:: jlcon

        julia> C = Const(42)
        julia> C(true), C(42), C([1, 2, 3])
        (42, 42, 42)

    Example: *identity* combinator.

    .. code-block:: julia

        This() = x -> x

    .. code-block:: jlcon

        julia> I = This()
        julia> I(true), I(42), I([1, 2, 3])
        (true, 42, [1, 2, 3])


.. slide:: Field Extractor
   :level: 2

   ``Field(name)`` extracts a field value from a JSON object.

    .. code-block:: julia

        Field(name) = x -> x[name]

    .. code-block:: jlcon

        julia> Name = Field("name")
        julia> Name(Dict("name" => "RAHM", "surname" => "E", "salary" => 216210))
        "RAHM"

    .. code-block:: jlcon

        julia> Salary = Field("salary")
        julia> Salary(Dict("name" => "RAHM", "surname" => "E", "salary" => 216210))
        216210


.. slide:: Querying with Combinators
   :level: 2

    .. code-block:: julia

        Field(name) = x -> x[name]

    ``Field`` is a combinator constructor, a function that returns a combinator.

    ``Field("salary")`` is a JSON combinator, a function that maps JSON to JSON.

    Creating a combinator (*constructing a query*):

    .. code-block:: jlcon

        julia> Salary = Field("salary")

    Applying the combinator (*executing a query*):

    .. code-block:: jlcon

        julia> Salary(Dict("name" => "RAHM", "surname" => "E", "salary" => 216210))
        216210


Traversing the hierarchy
------------------------


.. slide:: Traversing the Hierarchy
   :level: 2

    *Find the names of all departments.*

    .. graphviz:: citydb-department-names.dot

    Need to traverse the hierarchical structure.


.. slide:: Traversing the Hierarchy: Query
   :level: 3

    *Find the names of all departments.*

    We certainly need field extractors:

    .. code-block:: julia

        Departments = Field("departments")
        Name = Field("name")

    Combine them with the *traversal* operator (``>>``):

    .. code-block:: julia

        Dept_Names = Departments >> Name


.. slide:: Traversing the Hierarchy: Output
   :level: 3

    *Find the names of all departments.*

    .. code-block:: julia

        Dept_Names = Departments >> Name

    .. code-block:: jlcon

        julia> Dept_Names(citydb)
        35-element Array{Any,1}:
         "WATER MGMNT"
         "POLICE"
         "GENERAL SERVICES"
         ⋮

    How is ``>>`` implemented?


.. slide:: Traversal Operator
   :level: 2

    Traversal operator ``(F >> G)`` sends the output of ``F`` to the input of
    ``G``.

    Naively:

    .. code-block:: julia

        (F >> G) = x -> G(F(x))

    But this doesn't work!

    .. code-block:: julia

        (Departments >> Name)(citydb)

    translates into

    .. code-block:: julia

        citydb["departments"]["name"]

    which fails because ``citydb["departments"]`` is an array.


.. slide:: Traversal Operator: Arrays as Streams
   :level: 3

    An array is not a value, but a stream of values.

    Traversal operator applies combinators to individual elements of the
    stream.

    When :math:`F(x)` is a scalar:

    .. math::

        (F \gg G):
        x \;\overset{F}{\longmapsto}\;
        F(x) \;\overset{G}{\longmapsto}\;
        G(F(x))

    However, when :math:`F(x)` is an array :math:`[y_1,\, y_2,\, \ldots]`:

    .. math::

        (F \gg G):
        x \;\overset{F}{\longmapsto}\;
        [y_1,\, y_2,\, \ldots] \;\overset{G}{\longmapsto}\;
        [G(y_1),\, G(y_2),\, \ldots]

    ``Departments >> Name`` now works as expected.


.. slide:: Traversal Operator: Flattening
   :level: 3

    When :math:`F(x)` is an array:

    .. math::

        (F \gg G):
        x \;\overset{F}{\longmapsto}\;
        [y_1,\, y_2,\, \ldots] \;\overset{G}{\longmapsto}\;
        [G(y_1),\, G(y_2),\, \ldots]

    What if :math:`G(y_k)` are also arrays :math:`[z_{k1},\, z_{k2},\,
    \ldots]`?

    A value stream in a value stream?  Flatten it:

    .. math::

        (F \gg G):
        x \;\overset{F}{\longmapsto}\;
        [y_1,\, y_2,\, \ldots] \;\overset{G}{\longmapsto}\;
        [z_{11},\, z_{12},\, \ldots,\, z_{21},\, z_{22},\, \ldots]

    Also, :math:`\operatorname{null}` means lack of value.

    If :math:`G(y_k)` produces :math:`\operatorname{null}`, skip it.  Will use
    this later for filtering.


.. slide:: Traversal Operator: Flattening Example
   :level: 3

    *Find the names of all employees.*

    .. graphviz:: citydb-employee-names.dot

    .. code-block:: julia

        Departments = Field("departments")
        Employees = Field("epmployees")
        Name = Field("name")

        Empl_Names = Departments >> Employees >> Name


.. slide:: Traversal Operator: Flattening Example Output
   :level: 3

    *Find the names of all employees.*

    .. code-block:: julia

        Departments = Field("departments")
        Employees = Field("epmployees")
        Name = Field("name")

        Empl_Names = Departments >> Employees >> Name

    .. code-block:: jlcon

        julia> Empl_Names(citydb)
        32181-element Array{Any,1}:
         "ELVIA"
         "VICENTE"
         "MUHAMMAD"
         ⋮

    Traversal operator is associative.


.. slide:: Traversal Operator: Implementation
   :level: 3

    .. code-block:: julia

        (F >> G) = x -> _flat(_map(G, F(x)))

        _flat(z) =
            isa(z, Array) ? foldr(vcat, [], z) : z
        _map(G, y) =
            isa(y, Array) ? map(_expand, map(G, y)) : G(y)
        _expand(z_i) =
            isa(z_i, Array) ? z_i : z_i != nothing ? [z_i] : []


Summarizing data
----------------


.. slide:: Summarizing Data
   :level: 2

    *Find the number of departments.*

    Need a combinator that can count the number of elements in an array.

    Naively, define:

    .. code-block:: julia

        Count() = length

    Then use:

    .. code-block:: julia

        Departments = Field("departments")

        Num_Depts = Departments >> Count()

    Does not work!


.. slide:: Summarizing Data: Counting
   :level: 3

    *Find the number of departments.*

    .. code-block:: julia

        Count() = length

    .. code-block:: julia

        Num_Depts = Departments >> Count()

    Does not work!

    * ``Departments`` generates an array of departments;
    * Traversal (``>>``) will not let ``Count()`` see it as a whole;
    * Instead it will feed it to ``Count()`` one by one.

    What to do?


.. slide:: Summarizing Data: Counting 2
   :level: 3

    *Find the number of departments.*

    Pass an array-producing combinator as a parameter to ``Count()``:

    .. code-block:: julia

        Count(F) = x -> length(F(x))

    .. code-block:: julia

        Num_Depts = Count(Departments)

    .. code-block:: jlcon

        julia> Num_Depts(citydb)
        35


.. slide:: Aggregates and Traversal
   :level: 2

    How to properly combine aggregates and traversal?

    * *Count the number of employees for each department.*
    * *Count the total number of employees.*

    We need to combine traversal ``Departments >> Employees`` with ``Count()``.
    How?

.. slide:: Aggregates and Traversal: 2
   :level: 3

    *Count the number of employees for each department.*

    .. code-block:: julia

        Num_Empls_Per_Dept = Departments >> Count(Employees)

    .. code-block:: jlcon

        julia> Num_Empls_Per_Dept(citydb)
        35-element Array{Any,1}:
          1848
         13570
           924
             ⋮


.. slide:: Aggregates and Traversal: 3
   :level: 3

    *Count the number of employees for each department.*

    .. code-block:: julia

        Num_Empls_Per_Dept = Departments >> Count(Employees)

    * ``Departments`` produces a stream of department entities.
    * For each department, ``Count(Employees)`` calculates the number of
      employees.

    *Number of employees* is a property of each *department*.  This dictates
    the placement of ``>>``:

    .. math:: \textit{entity} \gg \textit{property}


.. slide:: Aggregates and Traversal: 4
   :level: 3

    *Count the total number of employees.*

    .. code-block:: julia

        Num_Empls = Count(Departments >> Employees)

    .. code-block:: jlcon

        julia> Num_Empls(citydb)
        32181

    *Total number of employees* is a global property.


.. slide:: Aggregates and Traversal: Conclusion
   :level: 3

    *Count the number of employees for each department.*

    .. code-block:: julia

        Num_Empls_Per_Dept = Departments >> Count(Employees)

    *Count the total number of employees.*

    .. code-block:: julia

        Num_Empls = Count(Departments >> Employees)

    Cannot differentiate between two cases with our original proposal:

    .. code-block:: julia

        Departments >> Employees >> Count()


.. slide:: Other Aggregates
   :level: 2

    *Find the top salary.*

    .. code-block:: julia

        Max(F) = x -> maximum(F(x))

    .. code-block:: julia

        Max_Salary = Max(Departments >> Employees >> Salary)

    .. code-block:: jlcon

        julia> Max_Salary(citydb)
        260004


.. slide:: Combining Aggregates
   :level: 2

    *Find the maximum number of employees among all departments.*

    We know how to *find the number of employees per department.*

    .. code-block:: julia

        Num_Empls_Per_Dept = Departments >> Count(Employees)

    Summarizing it, we *find the maximum.*

    .. code-block:: julia

        Max_Empls_Per_Dept = Max(Departments >> Count(Employees))

    .. code-block:: jlcon

        julia> Max_Empls_Per_Dept(citydb)
        13570


Constructing objects
--------------------


.. slide:: Constructing Objects
   :level: 2

    We learned to traverse and summarize data.  How to create new structured
    data?

    ``Select(...)`` constructs a new JSON object.

    .. code-block:: julia

        Select(fields...) =
            x -> Dict(map(f -> f.first => f.second(x), fields))

    Parameters of ``Select()``:

    * Field names;
    * Combinators for constructing field values.


.. slide:: Constructing Objects: Example
   :level: 3

    *Summarize the input array.*

    .. code-block:: jlcon

        julia> L = Count(This())
        julia> L([10, 20, 30])
        3

    .. code-block:: jlcon

        julia> M = Max(This())
        julia> M([10, 20, 30])
        30

    ``Select()`` passes its input to field constructors.

    .. code-block:: jlcon

        julia> S = Select("len" => Count(This()), "max" => Max(This()))
        julia> S([10, 20, 30])
        Dict{ASCIIString,Int64} with 2 entries:
          "len" => 3
          "max" => 30


.. slide:: Tabular Output
   :level: 2

    *For each department, find the number of employees.*

    We've done it already.

    .. code-block:: julia

        Num_Empls_Per_Dept = Departments >> Count(Employees)

    Now generate a table as an array of objects.

    .. code-block:: julia

        Depts_With_Size =
            Departments >> Select("name" => Name, "size" => Count(Employees))

    .. code-block:: jlcon

        julia> Depts_With_Size(citydb)
        35-element Array{Any,1}:
         Dict("name"=>"WATER MGMNT","size"=>1848)
         Dict("name"=>"POLICE","size"=>13570)
         ⋮


.. slide:: Tabular Output: Adding a Column
   :level: 3

    A new field could be added to ``Select()`` without changing other fields or
    the rest of the query.

    *For each department, find the number of employees and the top salary.*

    .. code-block:: julia

        Depts_With_Size_And_Max_Salary =
            Departments >> Select(
                "name" => Name,
                "size" => Count(Employees),
                "max_salary" => Max(Employees >> Salary))

    .. code-block:: jlcon

        julia> Depts_With_Size_And_Max_Salary(citydb)
        35-element Array{Any,1}:
         Dict("name"=>"WATER MGMNT","max_salary"=>169512,"size"=>1848)
         Dict("name"=>"POLICE","max_salary"=>260004,"size"=>13570)
         ⋮


Filtering data
--------------


.. slide:: Filtering
   :level: 2

    *Find the employees with salary greater than $200k.*

    Need a combinator that could filter data.  We'd like to write:

    .. code-block:: julia

        Very_Well_Paid_Empls =
            Departments >> Employees >> Sieve(Salary > 200000)

    .. code-block:: jlcon

        julia> Very_Well_Paid_Empls(citydb)
        3-element Array{Any,1}:
         Dict("name"=>"GARRY","surname"=>"M","position"=>"SUPERINTENDENT OF POLICE",
        "salary"=>260004)
         Dict("name"=>"JOSE","surname"=>"S","position"=>"FIRE COMMISSIONER","salary"=>202728)
         Dict("name"=>"RAHM","surname"=>"E","position"=>"MAYOR","salary"=>216210)

    How does ``Sieve()`` (and ``>``) work?


.. slide:: Filtering: ``Sieve()``
   :level: 3

    *Find the employees with salary greater than $200k.*

    .. code-block:: julia

        Very_Well_Paid_Empls =
            Departments >> Employees >> Sieve(Salary > 200000)

    Define:

    .. code-block:: julia

        Sieve(P) = x -> P(x) ? x : nothing

    Traversal (``>>``) operates on a stream of values.  It interprets
    ``nothing`` as *a no-value* and throws it out from the output stream.

    ``Sieve()`` needs predicate combinators (``>``, etc).


.. slide:: Filtering: Predicates
   :level: 3

    *Find the employees with salary greater than $200k.*

    .. code-block:: julia

        Very_Well_Paid_Empls =
            Departments >> Employees >> Sieve(Salary > 200000)

    .. code-block:: julia

        Sieve(P) = x -> P(x) ? x : nothing

    A predicate is a combinator that returns ``true`` or ``false``.

    .. code-block:: julia

        (>)(F::Function, G::Function) = x -> F(x) > G(x)
        (>)(F::Function, n::Number) = F > Const(n)


.. slide:: How Filtering Works?
   :level: 2

    .. code-block:: jlcon

        julia> Salary = Field("salary")
        julia> Salary(Dict("name" => "RAHM", "surname" => "E", "salary" => 216210))
        216210
        julia> Salary(Dict("name" => "STEVEN", "surname" => "K", "salary" => 1))
        1

    .. code-block:: jlcon

        julia> P = Salary > 200000
        julia> P(Dict("name" => "RAHM", "surname" => "E", "salary" => 216210))
        true
        julia> P(Dict("name" => "STEVEN", "surname" => "K", "salary" => 1))
        false

    .. code-block:: jlcon

        julia> F = Sieve(P)
        julia> F(Dict("name" => "RAHM", "surname" => "E", "salary" => 216210))
        Dict("name"=>"RAHM","surname"=>"E","salary"=>216210)
        julia> F(Dict("name" => "STEVEN", "surname" => "K", "salary" => 1))
        nothing


.. slide:: Filtering and Traversal
   :level: 2

    We can insert ``Sieve()`` to the traversal chain.

    *Find departments with more than 1000 employees.*

    .. code-block:: julia

        Large_Depts =
            Departments >> Sieve(Count(Employees) > 1000) >> Name

    .. code-block:: jlcon

        julia> Large_Depts(citydb)
        7-element Array{Any,1}:
         "WATER MGMNT"
         "POLICE"
         "STREETS & SAN"
         ⋮


.. slide:: Filtering and Selection
   :level: 2

    In the same manner, ``Sieve()`` can be combined with ``Select()``:

    *Find departments with more than 1000 employees.*

    .. code-block:: julia

        Size = Field("size")

        Large_Depts =
            Departments >> Select(
                "name" => Name,
                "size" => Count(Employees)) >> Sieve(Size > 1000)


.. slide:: Filtering and Aggregates
   :level: 2

    Aggregates and filtering could be combined in a number of ways.

    *Find the number of departments with more than 1000 employees.*

    .. code-block:: julia

        Num_Large_Depts =
            Count(Departments >> Sieve(Count(Employees) > 1000))

    .. code-block:: jlcon

        julia> Num_Large_Depts(citydb)
        7


.. slide:: Querying in Hierarchical Model
   :level: 2

    *For each department, find the number of employees with salary higher than
    $100k.*

    .. code-block:: julia

        Depts_With_Num_Well_Paid_Empls =
            Departments >>
            Select(
                "name" => Name,
                "N100k" => Count(Employees >> Sieve(Salary > 100000)))

    .. code-block:: jlcon

        julia> Depts_With_100k(citydb)
        35-element Array{Any,1}:
         Dict("name"=>"WATER MGMNT","N100k"=>179)
         Dict("name"=>"POLICE","N100k"=>1493)
         Dict("name"=>"GENERAL SERVICES","N100k"=>79)
         ⋮


.. slide:: Querying in Hierarchical Model: Comparison
   :level: 3

    *For each department, find the number of employees with salary higher than
    $100k.*

    Was:

    .. code-block:: julia

        Depts_With_Num_Well_Paid_Empls(data) =
            map(d -> Dict(
                    "name" => d["name"],
                    "N100k" =>
                        length(filter(e -> e["salary"] > 100000, d["employees"]))),
                data["departments"])

    Became:

    .. code-block:: julia

        Depts_With_Num_Well_Paid_Empls =
            Departments >> Select(
                "name" => Name,
                "N100k" => Count(Employees >> Sieve(Salary > 100000)))


Queries with parameters
-----------------------


.. slide:: Parameters
   :level: 2

    *Find the number of employees whose annual salary exceeds $200k.*  Easy:

    .. code-block:: julia

        Num_Well_Paid_Empls =
            Count(Departments >> Employees >> Sieve(Salary >= 200000))

    .. code-block:: jlcon

        julia> Num_Well_Paid_Empls(citydb)
        3

    *Find the number of employees with salary in a certain range.*

    * We don't know the range at the time we construct the query.
    * Instead, we submit the range when we execute the query.

    Need query parameters.


.. slide:: Parameters: Example
   :level: 3

    *Find the number of employees with salary in a certain range.*

    .. code-block:: julia

        Min_Salary = Var("min_salary")
        Max_Salary = Var("max_salary")

        Num_Empls_By_Salary =
            Count(
                Departments >>
                Employees >>
                Sieve((Salary >= Min_Salary) & (Salary < Max_Salary)))

    .. code-block:: jlcon

        julia> Num_Empls_By_Salary(citydb, "min_salary" => 100000, "max_salary" => 200000)
        3916


.. slide:: Parameters: Implementation
   :level: 3

    *Query context:* a dictionary of query parameters.  We pass context with input to
    all combinators.

    Need to make combinators context-aware.

    .. code-block:: julia

        Const(val) = (x, ctx...) -> val
        Field(name) = (x, ctx...) -> x[name]
        Count(F) = (x, ctx...) -> length(F(x, ctx...))
        ⋮

    Add context variable extractor.

    .. code-block:: julia

        Var(name) = (x, ctx...) -> Dict(ctx)[name]


.. slide:: Dynamic Parameters
   :level: 2

    *Find the employee with the highest salary.*

    Can do it with two queries.  First, *find the highest salary.*

    .. code-block:: jlcon

        julia> Max_Salary = Max(Departments >> Employees >> Salary)
        julia> Max_Salary(citydb)
        260004

    Then, *find the employee with the given salary.*

    .. code-block:: jlcon

        julia> The_Salary = Var("salary")
        julia> Empl_With_Salary = Departments >> Employees >> Sieve(Salary == The_Salary)
        julia> Empl_With_Salary(citydb, salary => 260004)
        1-element Array{Any,1}:
         Dict("name"=>"GARRY","surname"=>"M","position"=>"SUPERINTENDENT OF POLICE",
        "salary"=>260004)

    Can we do it in one query?


.. slide:: Dynamic Parameters: Example
   :level: 3

    *Find the employee with the highest salary.*

    1. Find the highest salary and assign the value to the ``salary`` variable.
    2. Find the employees with the given salary.

    Combinator ``Given()`` implements these two operations.

    .. code-block:: julia

        Max_Salary = Max(Departments >> Employees >> Salary)

        The_Salary = Var("salary")
        Empl_With_Salary = Departments >> Employees >> Sieve(Salary == The_Salary)

    .. code-block:: julia

        Empl_With_Max_Salary =
            Given(Empl_With_Salary, "salary" => Max_Salary)


.. slide:: Dynamic Parameters: Implementation
   :level: 3

    Combinator ``Given()`` adds a variable to the query context.

    .. code-block:: julia

        Given(F, vars...) =
            (x, ctx...) ->
                let ctx = (ctx..., map(v -> v.first => v.second(x, ctx...), vars)...)
                    F(x, ctx...)
                end


.. slide:: Dynamic Parameters and Traversal
   :level: 2

    *Find the employee with the highest salary.*

    .. code-block:: julia

        Empl_With_Max_Salary =
            Given(
                Departments >> Employees >> Sieve(Salary == The_Salary),
                "salary" => Max(Departments >> Employees >> Salary))

    *Find the employee with the highest salary at each department.*

    Pull ``Departments`` out of ``Given()``:

    .. code-block:: julia

        Top_Empl_By_Dept =
            Departments >> Given(
                Employees >> Sieve(Salary == The_Salary),
                "salary" => Max(Employees >> Salary))

    Cannot be done without query context.


Limitations
-----------


.. slide:: Limitations
   :level: 2

    In 50 lines, we created a capable query language for hierarchical
    databases.

    We were able to construct queries to answer all our questions.  Is it
    always the case?

    Consider: *Find the top salary for each department.*

    .. code-block:: julia

        Max_Salary_By_Dept =
            Departments >> Select(
                "name" => Name,
                "max_salary" => Max(Employees >> Salary))

    Now consider: *Find the top salary for each position*.

    One is easy, the other appears to be impossible.  Why?

    It's all about the structure.


.. slide:: Limitations: When It Works
   :level: 3

    *Find the top salary for each department.*

    .. graphviz:: citydb-max-salary-by-department.dot

    .. code-block:: julia

        Max_Salary_By_Dept =
            Departments >> Select(
                "name" => Name,
                "max_salary" => Max(Employees >> Salary))


.. slide:: Limitations: When It Doesn't
   :level: 3

    *Find the top salary for each position.*

    .. graphviz:: citydb-max-salary-by-position.dot

    The structure of the query does not map to the structure of the database.


.. slide:: Limitations: Shape
   :level: 3

    *Find the top salary for each position.*

    If only we could shape the data differently.

    .. graphviz:: citydb-max-salary-by-position-reshaped.dot

    .. code-block:: julia

        Max_Salary_By_Posn =
            Positions >> Select(
                "title" => Title,
                "max_salary" => Max(Employees >> Salary))


.. slide:: Hierarchy
   :level: 2

    Real databases are decidedly non-hierarchical.

    .. image:: RexStudy_Data_Model.png
       :scale: 50%

    This is RexDB_ database schema.  No hierarchy in sight!  Or, perhaps,
    many hierachies lumped together?

    .. _RexDB: http://www.rexdb.org/


.. slide:: Hierarchy 2
   :level: 3

    .. graphviz:: citydb-non-hierarchical.dot

    Many ways to make the sample database non-hierarchical:

    1. Expose both *department* and *position* as dimensions of *employee*.

    2. Note that relationship between *department* and *employee* is
       bi-directional.

    3. Add a relationship *manager* between *employees*, which cannot be
       represented in a finite hierarchy.


.. slide:: Conclusion
   :level: 2

   Combinators are awesome for querying data as long as:

   1. Data is hierarchical.
   2. Structure of the query respects the structure of the data.

   Otherwise, we are out of luck...

   *... Or are we?*

