Domains and input/output types
==============================


Domains
-------

A `Domain` object represents the type of a database object or a value.  It may
belong to one of three categories: value types, entity classes, and records.

    using RBT:
        Domain,
        Output,
        Void,
        None,
        classname,
        datatype,
        decorate,
        decoration,
        decorations,
        fields,
        isany,
        isdata,
        isentity,
        isrecord,
        isvoid,
        isnone,
        setplural

Value types, such as `Bool`, `Int` or `String`, are represented by native Julia
types.

    text_t = Domain(String)
    #-> String

Nominal entity classes are represented by the name of the class.

    dept_t = Domain(:Dept)
    #-> Dept

Structural records are declared by enumerating the types of the fields.

    name_and_salary_t = Domain((String, Int64))
    #-> {String, Int64}

In general, a record field may be of an entity or a record type and may have
non-trivial cardinality.  Such fields could be specified as `Domain` or
`Output` instances.

    name_and_salary_seq_t = Output(name_and_salary_t) |> setplural(true)

    dept_with_name_and_salary_seq_t = Domain((dept_t, name_and_salary_seq_t))
    #-> {Dept, {String, Int64}+}

Three special value types are recognized: the type `None` with no values, the
type `Void` with a distinguished singleton value, and the type `Any` of all
values.

    none_t = Domain(None)
    #-> None

    void_t = Domain(Void)
    #-> Void

    any_t = Domain(Any)
    #-> Any

Predicates `isdata()`, `isentity()`, `isrecord()` identify the category of the
domain.

    isdata(text_t)
    #-> true

    isdata(dept_t)
    #-> false

    isentity(dept_t)
    #-> true

    isentity(name_and_salary_t)
    #-> false

    isrecord(name_and_salary_t)
    #-> true

    isrecord(text_t)
    #-> false

Similarly, predicates `isnone()`, `isvoid()`, `isany()` identify special value
types.

    isnone(none_t)
    #-> true

    isnone(void_t)
    #-> false

    isvoid(void_t)
    #-> true

    isvoid(any_t)
    #-> false

    isany(any_t)
    #-> true

    isany(none_t)
    #-> false

Function `datatype()` returns the native Julia type that can represent domain
values.

    datatype(text_t)
    #-> String

    datatype(dept_t)
    #-> Dept

    datatype(name_and_salary_t)
    #-> Tuple{String,Int64}

Function `classname()` returns the name of an entity class.

    classname(dept_t)
    #-> :Dept

    classname(text_t)
    #-> Symbol("")

Function `fields()` returns a tuple with record fields.

    fields(name_and_salary_t)
    #-> RBT.Output[String,Int64]

    fields(text_t)
    #-> RBT.Output[]

The domain could be annotated with arbitrary values, which are called
*decorations*.

    name_t = text_t |> decorate(:tag => :name)
    #-> String[tag=:name]

Function `decoration()` returns the value for a specific decoration.

    decoration(name_t, :tag, Symbol, Symbol(""))
    #-> :name

    decoration(text_t, :tag, Symbol, Symbol(""))
    #-> Symbol("")

Function `decorations()` returns a list of all decorations.

    decorations(name_t)
    #-> Pair{Symbol,Any}[Pair{Symbol,Any}(:tag,:name)]


Output type
-----------

The *output type* describes the structure of the query output.  It includes the
output domain and the output cardinality.

    using RBT:
        Decoration,
        Domain,
        Output,
        OutputMode,
        Void,
        decoration,
        decorations,
        domain,
        isdata,
        isentity,
        isoptional,
        isplain,
        isplural,
        isrecord,
        isvoid,
        mode,
        setoptional,
        setplural

The output *cardinality* specifies whether the output is *optional* (may have
no value), *plural* (may have more than one value) or both.  Cardinalities are
represented by `OutputMode` objects.

    iso_mode = OutputMode()
    #-> RBT.OutputMode(false,false)

    opt_mode = iso_mode |> setoptional(true)
    #-> RBT.OutputMode(true,false)

    seq_mode = opt_mode |> setplural(true)
    #-> RBT.OutputMode(true,true)

    isplain(iso_mode)
    #-> true

    isplain(seq_mode)
    #-> false

    isplural(seq_mode)
    #-> true

    isplural(opt_mode)
    #-> false

    isoptional(opt_mode)
    #-> true

    isoptional(iso_mode)
    #-> false

The output type consists of the output domain and the output cardinality.  The
output type is created with the `Output` constructor.

    text_ot = Output(String)
    #-> String

    void_ot = Output(Domain(Void))
    #-> Void

    name_ot = text_ot |> decorate(:tag => :name)
    #-> String[tag=:name]

    department_ot = Output(:Dept) |> setoptional() |> setplural() |> decorate(:tag => :department)
    #-> Dept[tag=:department]*

    manager_ot =
        Output(
            Domain(:Emp, [Decoration(:tag, :manager)]),
            OutputMode(true, false))
    #-> Emp[tag=:manager]?

    subordinate_ot = manager_ot |> setplural() |> decorate(:tag => :subordinate)
    #-> Emp[tag=:subordinate]*

    record_ot = (
        Output([
            Output(String) |> decorate(:tag => :name),
            Output(Int64) |> decorate(:tag => :salary)])
        |> setplural()
        |> decorate(:tag => :employee))
    #-> {String[tag=:name], Int64[tag=:salary]}[tag=:employee]+

Components of the output type could be extracted using functions `domain()` and
`mode()`.

    domain(department_ot)
    #-> Dept[tag=:department]

    mode(department_ot)
    #-> RBT.OutputMode(true,true)

Various predicates and accessors can be used to inspect output types.

    isdata(text_ot)
    #-> true

    isentity(manager_ot)
    #-> true

    isrecord(record_ot)
    #-> true

    isvoid(void_ot)
    #-> true

    isplain(name_ot)
    #-> true

    isoptional(manager_ot)
    #-> true

    isplural(subordinate_ot)
    #-> true

    decoration(department_ot, :tag, Symbol, Symbol(""))
    #-> :department

    decoration(text_ot, :tag, Symbol, Symbol(""))
    #-> Symbol("")

Function `datatype()` returns a Julia type that can represent the output values
with the given output type.

    datatype(text_ot)
    #-> String

    datatype(manager_ot)
    #-> Nullable{Emp}

    datatype(record_ot)
    #-> Array{Tuple{String,Int64},1}


Input type
----------

The *input type* describes the form of the query input.  It includes the
input domain, the input *parameters*, and the *flow dependency* indicator.

    using RBT:
        Domain,
        Input,
        InputMode,
        InputParameter,
        Void,
        domain,
        isdata,
        isentity,
        isfree,
        isrelative,
        mode,
        parameters,
        setparameters,
        setrelative

The input context includes the input parameters and flow dependency indicator.
It is represented by `InputMode` object.

    free_mode = InputMode()
    #-> RBT.InputMode(false,Pair{Symbol,RBT.Output}[])

    rel_mode = free_mode |> setrelative()
    #-> RBT.InputMode(true,Pair{Symbol,RBT.Output}[])

    param_mode =
        rel_mode |> setrelative(false) |> setparameters([InputParameter(:D,:Dept), InputParameter(:S,Int64)])
    #-> RBT.InputMode(false,Pair{Symbol,RBT.Output}[:D=>Dept,:S=>Int64])

    isfree(free_mode)
    #-> true

    isfree(rel_mode)
    #-> false

    isrelative(rel_mode)
    #-> true

    isrelative(param_mode)
    #-> false

    parameters(param_mode)
    #-> Pair{Symbol,RBT.Output}[:D=>Dept,:S=>Int64]

    parameters(free_mode)
    #-> Pair{Symbol,RBT.Output}[]

The input type is created using the `Input` constructor.

    void_it = Input(Void)
    #-> Void

    dept_rel_it = Input(:Dept) |> setrelative()
    #-> (Dept...)

    emp_param_it =
        Input(:Emp, InputMode(false, [InputParameter(:S, Output(Int64) |> setoptional())]))
    #-> {Emp, S => Int64?}

Components of the input type could be extracted using functions `domain()` and
`mode()`.

    domain(dept_rel_it)
    #-> Dept

    mode(dept_rel_it)
    #-> RBT.InputMode(true,Pair{Symbol,RBT.Output}[])

Various predicates and accessors can be used to inspect the input type.

    isdata(void_it)
    #-> true

    isentity(dept_rel_it)
    #-> true

    isfree(void_it)
    #-> true

    isrelative(dept_rel_it)
    #-> true

    parameters(emp_param_it)
    #-> Pair{Symbol,RBT.Output}[:S=>Int64?]


Domain lattice
--------------

Domains are partially ordered with respect to inclusion.

    using RBT:
        Decoration,
        Domain,
        Input,
        InputMode,
        InputParameter,
        Output,
        OutputMode,
        fits,
        ibound,
        obound

We say that domain *A* *fits* domain *B* if all the values of *A* are also the
values of *B*.  Function `fits()` verifies this property.

    fits(Domain(Int64), Domain(Real))
    #-> true

    fits(Domain(Int64), Real)
    #-> true

    fits(Domain(Int64), Domain(Float64))
    #-> false

    fits(Domain(:Dept), Domain(:Dept))
    #-> true

    fits(Domain(:Dept), Domain(:Emp))
    #-> false

    fits(Domain(:Dept), Domain((String,)))
    #-> false

    fits(
        Domain((Output(:Dept), Output(Int64))),
        Domain((Output(:Dept) |> setplural(), Output(Real))))
    #-> true

    fits(
        Domain((Output(:Dept) |> setoptional(),)),
        Domain((Output(:Dept),)))
    #-> false

We can also use `fits()` to verify that the output of one query fits the input
of another query.

    fits(Output(:Dept) |> setplural(), Input(:Dept) |> setrelative())
    #-> true

    fits(Output(:Dept), Input(:Emp))
    #-> false

Finally, we can check if the given input type fits the expected input type.

    fits(Input(String) |> setrelative(), Input(String))
    #-> true

    fits(Input(String), Input(String) |> setrelative())
    #-> false

    fits(
        Input(:Dept) |> setparameters([InputParameter(:S, Int64)]),
        Input(:Dept) |> setparameters([InputParameter(:S, Output(Int64) |> setoptional())]))
    #-> true

    fits(Input(:Dept), Input(:Dept) |> setparameters([InputParameter(:S, Int64)]))
    #-> false

For any two domains, the smallest domain that encapsulates both of them is
called their *output bound*.

    obound(Domain(String), Domain(String))
    #-> String

    obound(Domain(Int64), Domain(Float64))
    #-> Real

    obound(Domain(:Dept), Domain(:Dept))
    #-> Dept

    obound(Domain(:Dept), Domain(:Emp))
    #-> Any

    obound(Domain(:Dept), Domain(String))
    #-> Any

    obound(
        Domain((:Dept, String, Output(Int64) |> setoptional())),
        Domain((:Emp, String, Output(Float64) |> setplural())))
    #-> {Any, String, Real*}

    obound(
        Domain((:Dept,)),
        Domain((:Dept, String)))
    #-> Any

The output bound is also calculated for domain decorations.

    obound(
        Domain(String) |> decorate(:tag => :name),
        Domain(String) |> decorate(:tag => :name))
    #-> String[tag=:name]

    obound(
        Domain(Int64) |> decorate(:tag => :salary),
        Domain(Float64) |> decorate(:precision => 2))
    #-> Real[tag=:salary]

    obound(
        Domain(:Emp) |> decorate(:tag => :employee),
        Domain(:String) |> decorate(:tag => :name))
    #-> Any[tag=?]

Similarly, we can find the output bound of two output types.

    obound(Output(String), Output(String))
    #-> String

    obound(
        Output(Int64) |> setoptional(),
        Output(Float64) |> setplural())
    #-> Real*

Similarly, for any two domains, the largest domain that fits both of them is
called their *input bound*.

    ibound(Domain(String), Domain(String))
    #-> String

    ibound(Domain(Int64), Domain(Float64))
    #-> None

    ibound(Domain(:Emp), Domain(:Emp))
    #-> Emp

    ibound(Domain(:Emp), Domain(:Dept))
    #-> None

    ibound(Domain((:Emp, String)), Domain((:Emp, String)))
    #-> {Emp, String}

    ibound(Domain((:Emp, String)), Domain((:Emp, String, Int64)))
    #-> None

    ibound(
        Domain((
            Output(String) |> setoptional() |> decorate(:tag => :name),
            Output(String) |> setoptional() |> decorate(:tag => :position))),
        Domain((
            Output(String) |> setplural() |> decorate(:tag => :name),
            Output(:Dept) |> setoptional() |> decorate(:tag => :department))))
    #-> {String[tag=:name], None?}

Functions `ibound()` and `obound()` could also be applied to the input contexts
and output cardinalities.

    obound(OutputMode)
    #-> RBT.OutputMode(false,false)

    obound(OutputMode() |> setoptional())
    #-> RBT.OutputMode(true,false)

    obound(OutputMode() |> setoptional(), OutputMode() |> setoptional() |> setplural())
    #-> RBT.OutputMode(true,true)

    ibound(OutputMode)
    #-> RBT.OutputMode(true,true)

    ibound(OutputMode() |> setoptional())
    #-> RBT.OutputMode(true,false)

    ibound(OutputMode() |> setoptional(), OutputMode() |> setoptional() |> setplural())
    #-> RBT.OutputMode(true,false)

Both `ibound()` and `obound()` could be applied to an arbitrary number of
domains.

    obound(Domain)
    #-> None

    obound(Domain(:Dept))
    #-> Dept

    obound(Domain(UInt8), Domain(UInt16), Domain(UInt32))
    #-> Unsigned

    ibound(Domain)
    #-> Any

    ibound(Domain(:Dept))
    #-> Dept

    ibound(Domain(Int32), Domain(Union{Int16,Int32}), Domain(Union{Int32,Int64}))
    #-> Int32

