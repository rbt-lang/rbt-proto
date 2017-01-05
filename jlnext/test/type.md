Domains and signatures
======================


Entity classes
--------------

Entity classes represent abstract concepts such as *departments* or
*employees*.  They are distinguished by their *class name*.  The actual type of
entity values depends on the data source, but when they are exposed to the
user, they are wrapped into containers of type `Entity`.

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


Domains
-------

A `Domain` object represents the type of a database object or a value.  It may
belong to one of three categories: value types, entity classes, and records.

    using RBT:
        Domain,
        Output,
        Unit,
        Zero,
        classname,
        datatype,
        fields,
        isany,
        isdata,
        isentity,
        isrecord,
        isunit,
        iszero

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

    name_and_salary_seq_t = Output(name_and_salary_t, plural=true)

    dept_with_name_and_salary_seq_t = Domain((dept_t, name_and_salary_seq_t))
    #-> {Dept, {String, Int64}+}

Three special value types are recognized: the type `Zero` with no values, the
type `Unit` with a distinguished singleton value, and the type `Any` of all
values.

    zero_t = Domain(Zero)
    #-> Zero

    unit_t = Domain(Unit)
    #-> Unit

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

Similarly, predicates `iszero()`, `isunit()`, `isany()` identify special value
types.

    iszero(zero_t)
    #-> true

    iszero(unit_t)
    #-> false

    isunit(unit_t)
    #-> true

    isunit(any_t)
    #-> false

    isany(any_t)
    #-> true

    isany(zero_t)
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
    #-> (String,Int64)

    fields(text_t)
    #-> (String,)


Output signature
----------------

The *output signature* describes the form of the query output.  It includes the
output domain, the output cardinality, and the output decorations.

    using RBT:
        Domain,
        Output,
        OutputDecoration,
        OutputMode,
        Unit,
        decoration,
        decorations,
        domain,
        isdata,
        isentity,
        isoptional,
        isplain,
        isplural,
        isrecord,
        isunit,
        mode

The output *cardinality* specifies whether the output is *optional* (may have
no value), *plural* (may have more than one value) or both.  Cardinalities are
represented by `OutputMode` objects.

    iso_mode = OutputMode()
    #-> RBT.OutputMode(false,false)

    opt_mode = OutputMode(optional=true)
    #-> RBT.OutputMode(true,false)

    seq_mode = OutputMode(opt_mode, plural=true)
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

The output signature consists of the output domain, the output cardinality and
a sequence of *decorations*.  The signature is created with the `Output`
constructor.

    text_osig = Output(String)
    #-> String

    unit_osig = Output(Domain(Unit))
    #-> Unit

    name_osig = Output(text_osig, tag=:name)
    #-> String [tag=:name]

    department_osig = Output(:Dept, optional=true, plural=true, tag=:department)
    #-> Dept* [tag=:department]

    manager_osig =
        Output(
            Domain(:Emp),
            OutputMode(optional=true),
            (OutputDecoration(:tag,:manager),))
    #-> Emp? [tag=:manager]

    subordinate_osig = Output(manager_osig, plural=true, tag=:subordinate)
    #-> Emp* [tag=:subordinate]

    record_osig =
        Output(
            (Output(String, tag=:name), Output(Int64, tag=:salary)),
            plural=true,
            tag=:employee)
    #-> {String [tag=:name], Int64 [tag=:salary]}+ [tag=:employee]

Components of the signature could be extracted using functions `domain()`,
`mode()` and `decorations()`.

    domain(department_osig)
    #-> Dept

    mode(department_osig)
    #-> RBT.OutputMode(true,true)

    decorations(department_osig)
    #-> (Pair{Symbol,Any}(:tag,:department),)

Various predicates and accessors can be used to inspect output signatures.

    isdata(text_osig)
    #-> true

    isentity(manager_osig)
    #-> true

    isrecord(record_osig)
    #-> true

    isunit(unit_osig)
    #-> true

    isplain(name_osig)
    #-> true

    isoptional(manager_osig)
    #-> true

    isplural(subordinate_osig)
    #-> true

    decoration(department_osig, :tag, Symbol(""))
    #-> :department

    decoration(text_osig, :tag, Symbol(""))
    #-> Symbol("")

Function `datatype()` returns a Julia type that can represent the output values
with the given signature.

    datatype(text_osig)
    #-> String

    datatype(manager_osig)
    #-> Nullable{Emp}

    datatype(record_osig)
    #-> Array{Tuple{String,Int64},1}


Input signature
---------------

The *input signature* describes the form of the query input.  It includes the
input domain, the input *parameters*, and the *flow dependency* indicator.

    using RBT:
        Domain,
        Input,
        InputMode,
        InputParameter,
        Unit,
        domain,
        isdata,
        isentity,
        isfree,
        isrelative,
        mode,
        parameters

The input context includes the input parameters and flow dependency indicator.
It is represented by `InputMode` object.

    free_mode = InputMode()
    #-> RBT.InputMode(false,())

    rel_mode = InputMode(relative=true)
    #-> RBT.InputMode(true,())

    param_mode = InputMode(
        rel_mode,
        relative=false,
        parameters=(InputParameter(:D,:Dept), InputParameter(:S,Int64)))
    #-> RBT.InputMode(false,(:D=>Dept,:S=>Int64))

    isfree(free_mode)
    #-> true

    isfree(rel_mode)
    #-> false

    isrelative(rel_mode)
    #-> true

    isrelative(param_mode)
    #-> false

    parameters(param_mode)
    #-> (:D=>Dept,:S=>Int64)

    parameters(free_mode)
    #-> ()

The input signature is created using the `Input` constructor.

    unit_isig = Input(Unit)
    #-> Unit

    dept_rel_isig = Input(:Dept, relative=true)
    #-> (Dept...)

    emp_param_isig = Input(
        dept_rel_isig,
        domain=:Emp,
        relative=false,
        parameters=(InputParameter(:S, Output(Int64, optional=true)),))
    #-> {Emp, S => Int64?}

Components of the input signature could be extracted using functions `domain()`
and `mode()`.

    domain(dept_rel_isig)
    #-> Dept

    mode(dept_rel_isig)
    #-> RBT.InputMode(true,())

Various predicates and accessors can be used to inspect the input signature.

    isdata(unit_isig)
    #-> true

    isentity(dept_rel_isig)
    #-> true

    isfree(unit_isig)
    #-> true

    isrelative(dept_rel_isig)
    #-> true

    parameters(emp_param_isig)
    #-> (:S=>Int64?,)


Domain lattice
--------------

Domains are partially ordered with respect to inclusion.

    using RBT:
        Domain,
        Input,
        InputMode,
        InputParameter,
        Output,
        OutputDecoration,
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
        Domain((Output(:Dept, plural=true), Output(Real))))
    #-> true

    fits(
        Domain((Output(:Dept, optional=true),)),
        Domain((Output(:Dept),)))
    #-> false

We can also use `fits()` to verify that the output of one query fits the input
of another query.

    fits(Output(:Dept, plural=true), Input(:Dept, relative=true))
    #-> true

    fits(Output(:Dept), Input(:Emp))
    #-> false

Finally, we can check if the given input signature fits the expected input
signature.

    fits(Input(String, relative=true), Input(String))
    #-> true

    fits(Input(String), Input(String, relative=true))
    #-> false

    fits(
        Input(:Dept, parameters=(InputParameter(:S, Int64),)),
        Input(:Dept, parameters=(InputParameter(:S, Output(Int64, optional=true)),)))
    #-> true

    fits(Input(:Dept), Input(:Dept, parameters=(InputParameter(:S, Int64),)))
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
        Domain((:Dept, String, Output(Int64, optional=true))),
        Domain((:Emp, String, Output(Float64, plural=true))))
    #-> {Any, String, Real*}

    obound(
        Domain((:Dept,)),
        Domain((:Dept, String)))
    #-> Any

We could also find the output bound of two output signatures.

    obound(Output(String, tag=:name), Output(String, tag=:name))
    #-> String [tag=:name]

    obound(
        Output(Int64, optional=true, tag=:salary),
        Output(Float64, plural=true))
    #-> Real* [tag=:salary]

    obound(
        Output(:Emp, tag=:employee),
        Output(String, tag=:name))
    #-> Any [tag=?]

Similarly, for any two domains, the largest domain that fits both of them is
called their *input bound*.

    ibound(Domain(String), Domain(String))
    #-> String

    ibound(Domain(Int64), Domain(Float64))
    #-> Zero

    ibound(Domain(:Emp), Domain(:Emp))
    #-> Emp

    ibound(Domain(:Emp), Domain(:Dept))
    #-> Zero

    ibound(Domain((:Emp, String)), Domain((:Emp, String)))
    #-> {Emp, String}

    ibound(Domain((:Emp, String)), Domain((:Emp, String, Int64)))
    #-> Zero

    ibound(
        Domain((Output(String, optional=true, tag=:name), Output(String, optional=true, tag=:position))),
        Domain((Output(String, plural=true, tag=:name), Output(:Dept, optional=true, tag=:department))))
    #-> {String [tag=:name], Zero?}

Functions `ibound()` and `obound()` could also be applied to the input contexts
and output cardinalities.

    obound(OutputMode)
    #-> RBT.OutputMode(false,false)

    obound(OutputMode(optional=true))
    #-> RBT.OutputMode(true,false)

    obound(OutputMode(optional=true), OutputMode(optional=true, plural=true))
    #-> RBT.OutputMode(true,true)

    ibound(OutputMode)
    #-> RBT.OutputMode(true,true)

    ibound(OutputMode(optional=true))
    #-> RBT.OutputMode(true,false)

    ibound(OutputMode(optional=true), OutputMode(optional=true, plural=true))
    #-> RBT.OutputMode(true,false)

Both `ibound()` and `obound()` could be applied to an arbitrary number of
domains.

    obound(Domain)
    #-> Zero

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

