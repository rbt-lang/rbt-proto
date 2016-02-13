Introduction
============

.. slide:: Combinators
   :level: 2

   **Definition:** *Combinator* is an expression with no free variables.

   **In a broad sense:** a design technique for implementing compositional
   domain-specific languages.

   A combinatorial DSL must define:

   * *primitives* or atomic combinators.
   * *composites* constructed from other combinators.

   **Combinators are composable.**

   Combinators with compatible interfaces could be composed in a variety of
   ways to form a composite processing pipeline.

   **Combinators are extensible.**

   A combinatorial DSL could be adapted to new domains by extending it with
   domain-specific combinators.


.. slide:: Database Queries as Combinators
   :level: 3

   Well-known examples of combinatorial DSLs:

   * Parsing combinators (building parsers out of smaller parsers).
   * Reactive graphics (constructing objects and behavior compositionally).

   We apply this technique to *querying a database*.

   **Database queries as combinators.**  For example, *primitives*:

    .. math::

        &\operatorname{department} & : \operatorname{Empl}&\to\operatorname{Dept} \\
        &\operatorname{name} & : \operatorname{Dept}&\to\operatorname{Text}

    *And a composite:*

    .. math::

        \operatorname{department}{.}\operatorname{name}: \operatorname{Empl} \to \operatorname{Text} \\


.. slide:: Why combinators?
   :level: 3

   But SQL is *the* query language since 1970s.  What combinators can give us
   that SQL cannot?

   Because combinators are composable, queries can ba constructed *incrementally*.
   This lets you:

   * Write new queries using *gradial refinement*.

   * Read unfamiliar queries by tracing the author's thoughts step by step.

   * Build queries *programmatically*.

   *There is an increasing need to bring the non-professional user into
   effective communication with a formatted data base.*  Chamberlin, D;
   Boyce, R (1974).

   Can we realize the dream of generations of query language designers: give
   the specialists direct access to their data?


.. slide:: Functional Data Model
   :level: 2

    Uses *sets* & set *functions*.

    * **Sets** model classes of entities.

    * **Functions** model entity attributes and relationships.

    Example: departments & employees of the city of Chicago
    (`source`_).

    .. graphviz:: citydb-functional-data-model.dot


.. slide:: Schema and Instance
   :level: 2

    .. math::

        \begin{matrix}
            \begin{matrix}
                \text{Schema} \\
                \small (\operatorname{Dept}, \operatorname{Empl},\, \ldots)
            \end{matrix} &
            \Rightarrow &
            \begin{matrix}
                \text{Instance} \\
                \small (\langle \texttt{"Rahm Emanuel"}, \texttt{"Mayor"} \rangle,\, \ldots)
            \end{matrix} \\
            & & \\
            \begin{matrix}
                \text{Type} \\
                \small (\operatorname{Int})
            \end{matrix} &
            \Rightarrow &
            \begin{matrix}
                \text{Value} \\
                \small (42\in\operatorname{Int})
            \end{matrix}
        \end{matrix}

    *Database schema* is like a data type.

    *Database instance* is like a value of the data type.


.. slide:: Asking Questions
   :level: 2

    Given a database, we may like to know:

    * *The number of departments in the city of Chicago.*
    * *The number of employees in each department.*
    * *The top salary among all the employees.*
    * *... and for each department.*
    * *The mean salary by position.*
    * *and much more...*

    Raw dataset does not contain immediate answers to these questions.

    Has enough information to infer the answers from the data.

    Need to traverse, transform, filter, summarize the data.

    How to ask questions about the data?


.. slide:: Query Syntax and Semantics
   :level: 2

    .. math::

        \begin{matrix}
            \begin{matrix}
                \text{Schema} \\
                \small (\operatorname{Dept}, \operatorname{Empl},\, \ldots)
            \end{matrix} &
            \Rightarrow &
            \begin{matrix}
                \text{Instance} \\
                \small (\langle \texttt{"Rahm Emanuel"}, \texttt{"Mayor"} \rangle,\, \ldots)
            \end{matrix} \\
            & & \\
            \Downarrow & & \Downarrow \\
            & & \\
            \begin{matrix}
                \text{Query} \\
                \small (\operatorname{count}(\operatorname{employee}))
            \end{matrix} &
            \Rightarrow &
            \begin{matrix}
                \text{Fact} \\
                \small (32181)
            \end{matrix}
        \end{matrix}

    **Query syntax:** How to form a question?

    **Query semantics:** How to interpret a question against some instance?


.. slide:: Query Syntax and Semantics: Trivial Database
   :level: 3

    .. math::

        \begin{matrix}
            \begin{matrix}
                \text{Type} \\
                \small (\operatorname{Int})
            \end{matrix} &
            \Rightarrow &
            \begin{matrix}
                \text{Value} \\
                \small (42\in\operatorname{Int})
            \end{matrix} \\
            & & \\
            \Downarrow & & \Downarrow \\
            & & \\
            \begin{matrix}
                \text{Property} \\
                \small (\operatorname{odd}: \operatorname{Int}\to\operatorname{Bool})
            \end{matrix} &
            \Rightarrow &
            \begin{matrix}
                \text{Property Value} \\
                \small (\operatorname{odd}: 42\mapsto\operatorname{false})
            \end{matrix}
        \end{matrix}

    .. math::

        \operatorname{odd}(x) := x \bmod 2 = 1

    Math notation is the query syntax.  Algebra is the query semantics.


.. slide:: The Objective
   :level: 2

    *Design syntax and semantics of a query language for functional data
    model.*

    For relational model: *SQL* and *relational algebra*.

    * Elementary unit: *tuple set*.
    * Elementary operation: *set product*.

    For functional model: **Rabbit**.

    * Elementary unit: *function*.
    * Elementary operation: *composition of functions*.

    We claim **Rabbit** is:

    * As powerful as SQL.
    * Easier to write and comprehend than SQL.
    * Has no gaps between syntax and semantics (is SQL relational?)


In computer science, the term *combinator* is used in a narrow and a broad
sense.  In a narrow definition, a combinator is any expression with no free
variables.  That is to say, a combinator expression has its value completely
determined by its structure.

In a broad sense, *combinator pattern* is a technique for designing
domain-specific languages (DSLs), which prescribes us to model domain-specific
operations in terms of self-contained composable processing blocks.  These
blocks should either come from a set of predefined atomic *primitives* or be
constructed from other blocks as *composites*.  Operations that combine blocks
to make composite blocks are often called combinators, which gave the name to
the technique, but it is the fact that that every block is self-contained that
connects this usage of the term with the narrow definition.  Going forward, we
will refer to individual blocks as well as the operations that combine them as
combinators.

Let us state two properties that make combinators attractive as a design
technique for DSLs.

* **Combinators are composable.**  A DSL is fully defined by its set of
  primitives and a set of operations for composing combinators.  Any
  composition operation must be defined in a generic way so that its operands
  could be any combinators with compatible interfaces.  This property gives
  combinatorial DSLs a distinctive feel of a "construction set".

* **Combinators are extensible.**  A combinatorial DSL could be adapted to new
  domains by extending it with new primitives or composite combinators.




What does it mean to design a database query language?  New *programming*
languages come in dozens every year and their taxonomy is well known.  Whether
it is functional vs. object-oriented, compiled or interpreted, statically or
dynamically typed, the designers can reasonably expect their audience not just
to be familiar with the notions, but also to hold a (strong) opinion on
them.  For that reason, a new programming language could be introduced with a
bullet list of features and highlights.

By contrast, the design space of query languages is largely uncharted.  New
query languages are quite rare and don't attract much interest either from
database experts or wider programming community.  It appears this subject is
regarded as a solved problem, with SQL and relational algebra being the optimal
solution.  We disagree, but before we can present our case, we need to mark the
playing field.

Databases come in many forms.  A series of measurements over a period of time,
or a collection of HTML documents are databases, but we will not be concerned
about them.  Instead, we are interested in databases of highly structured,
heterogenous data that describe business processes.  It could be a database
describing organizational structure of a company, or a database tracking
patients and doctors in a hospital, or a database that backs some web
application.

Let us recall some basic database theory.  *A data model* defines terms and
concepts for describing business entities, their attributes and relationships
with each other.  *A database schema* describes the structure of a particular
data collection.  We say that a data model is a framework for making database
schemas.

We will be exploring *the functional data model*, which structures data in
terms of sets and set functions.  Classes of entities are modeled as sets.
Attributes of entities and relationships between entities are modeled as
functions on sets. [#spivak]_

.. admonition:: Example
   :class: note

    Our running example is based on the dataset of employees of the City of
    Chicago (source_).  In functional data model, it can be presented as
    follows:

    .. graphviz:: citydb-functional-data-model.dot

    Here, :math:`\operatorname{Dept}` is a set of all departments,
    :math:`\operatorname{Empl}` is a set of all employees,
    :math:`\operatorname{Text}` is a set of all text strings,
    :math:`\operatorname{Int}` is a set of integer numbers.

    Function
    :math:`\operatorname{name}:\operatorname{Dept}\to\operatorname{Text}` maps
    department entities to their names,
    :math:`\operatorname{salary}:\operatorname{Empl}\to\operatorname{Int}` sets
    employee's annual salary,
    :math:`\operatorname{department}:\operatorname{Empl}\to\operatorname{Dept}`
    assigns each employee to their department, and so on.

    We treat elements of the entity sets as opaque values that can be passed
    around or compared by identity, but cannot be directly observed.  We denote
    them as

    .. math::

        \mathit{dept}_1,\, \mathit{dept}_2,\, \mathit{dept}_3,\, \ldots, \qquad
        \mathit{empl}_1,\, \mathit{empl}_2,\, \mathit{empl}_3,\, \ldots

    Individual entities can be examined by use of functions defined by the
    schema.  To learn the name of a particular department, we apply the
    :math:`\operatorname{name}:\operatorname{Dept}\to\operatorname{Text}`
    function to the entity value:

    .. math::

        \operatorname{name}: \mathit{dept}_1 \mapsto \texttt{"WATER MGMNT"}

    To relate an employee to their department, we apply the
    :math:`\operatorname{department}:\operatorname{Empl}\to\operatorname{Dept}`
    function:

    .. math::

        \operatorname{department}: \mathit{empl}_1 \mapsto \mathit{dept}_1

    If we compose :math:`\operatorname{department}` and
    :math:`\operatorname{name}`, we get a function that maps each employee to
    the name of their department:

    .. math::

        & \operatorname{department}{.}\operatorname{name}: \operatorname{Empl} \to \operatorname{Text} \\
        & \operatorname{department}{.}\operatorname{name}: \mathit{empl}_1 \mapsto \texttt{"WATER MGMNT"}

    Operator :math:`.` (period) denotes composition of functions:
    :math:`(f{.}g)(x) = g(f(x))`.

.. _source: https://data.cityofchicago.org/Administration-Finance/Current-Employee-Names-Salaries-and-Position-Title/xzkq-xp2w

The diagram above resembles an entity-relationship diagram and, in fact, any
ERD can be rewritten in terms of sets and functions.  We transform an entity
node to a set of homogeneous entities.  Then an entity attribute becomes a
function defined on an entity set that maps each entity to the attribute value.
A relationship between two entities can be expressed as a function mapping one
type of entitites to the other.  As long as we can identify classes of entities
with a fixed set of attributes and relationships, we can use functional data
model to structure the data.

*A database instance* is a snapshot of data stored in the database at some
particular moment.  Any instance must obey the structure imposed by the schema.

In our example, the schema defines types of entities (*Departments*,
*Employees*), their attributes (*name*, *position*, *salary*) and relationships
(*an employee works in a department*).  A specific instance enumerates concrete
entities (*Police Department*, *Fire Department*, etc) and assigns attribute
values (*position* of *Rahm Emanuel* is *Mayor*).

.. math::

    \begin{matrix}
        \begin{matrix}
            \text{Schema} \\
            \small (\operatorname{Dept},\, \operatorname{Empl},\, \ldots)
        \end{matrix} &
        \Rightarrow &
        \begin{matrix}
            \text{Instance} \\
            \small (\{ \texttt{"POLICE"}, \texttt{"FIRE"}, \ldots \},\, \ldots)
        \end{matrix}
    \end{matrix}

The relation between a schema and its instance is much the same as between a
data type and a value of the type.  Indeed, we can think of a data type as of a
trivial "database schema".  Then any value of this type becomes a "database
instance". (And a variable a "database storage"?  Then what is a "database
query"?)

.. math::

    \begin{matrix}
        \begin{matrix}
            \text{Type} \\
            \small (\operatorname{Int})
        \end{matrix} &
        \qquad\Rightarrow\qquad &
        \begin{matrix}
            \text{Value} \\
            \small (42 : \operatorname{Int})
        \end{matrix}
    \end{matrix}

A database is useful as long as we can retrieve the data from it.  But what
exactly does it mean to retrieve the data?  As a rule, we ask not for the
entire content of the database, but rather for some information that could be
deduced from the data.

Going back to our sample dataset, one may ask:

1. *What are the departments in the city of Chicago?*
2. *How many employees in each department?*
3. *What is the top salary among all the employees?*
4. *... and for each department?*
5. *The mean salary by position?*

*and much more...*

It is not quite obvious if the database contains any answers to these
questions.  The database schema defines :math:`\operatorname{Dept}`, the set of
all departments, so we may expect to be able to retrieve its content, which
should answer the first question.  On the other hand, the schema does not
define any attributes called *the number of employees* or *the top salary*.
And yet this knowledge can be inferred from the database as long as the
database system is willing to transform, filter and summarize its content.

To have a meaningful conversation about data retrieval, we need another
dimension of the data model.  *A database query* is any question about the data
that is valid in the given data model and can be answered by the database
system.  *A fact* is an answer to the query for a specific database instance.
[#diagram]_

.. math::

    \begin{matrix}
        \begin{matrix}
            \text{Schema} \\
            \small (\operatorname{Dept}, \operatorname{Empl},\, \ldots)
        \end{matrix} &
        \Rightarrow &
        \begin{matrix}
            \text{Instance} \\
            \small (\{ \texttt{"POLICE"}, \texttt{"FIRE"}, \ldots \},\, \ldots)
        \end{matrix} \\
        & & \\
        \Downarrow & & \Downarrow \\
        & & \\
        \begin{matrix}
            \text{Query} \\
            \small (\operatorname{count}(\operatorname{employee}))
        \end{matrix} &
        \Rightarrow &
        \begin{matrix}
            \text{Fact} \\
            \small (32181)
        \end{matrix}
    \end{matrix}

To be complete, a data model must specify how to form valid queries and how to
interpret any query for any database instance.  In other words, a data model must
come with syntax and semantics of *a query language*.

Let us extend the parallel between databases and data types.  If a data type is
a "database schema", and a value of a data type is a "database instance", then
a "database query" would be any property of the type, that is, any function
defined on values of this particular data type, and a "fact" would be a value
of the property.

.. math::

    \begin{matrix}
        \begin{matrix}
            \text{Type} \\
            \small (\operatorname{Int})
        \end{matrix} &
        \quad\Rightarrow\quad &
        \begin{matrix}
            \text{Value} \\
            \small (42 : \operatorname{Int})
        \end{matrix} \\
        & & \\
        \Downarrow & & \Downarrow \\
        & & \\
        \begin{matrix}
            \text{Property} \\
            \small (\operatorname{odd}: \operatorname{Int}\to\operatorname{Bool})
        \end{matrix} &
        \quad\Rightarrow\quad &
        \begin{matrix}
            \text{Property Value} \\
            \small (\operatorname{odd}: 42\mapsto\operatorname{false})
        \end{matrix}
    \end{matrix}

A particular "query" could be defined using mathematical notation:

.. math::

    \operatorname{odd}(x) := x \bmod 2 = 1

We interpret this "query" on a given "instance" using the rules of algebra:

.. math::

    \operatorname{odd} : 42 \mapsto (42 \bmod 2 = 1) = (0 = 1) = \operatorname{false}.

The database technologies currently dominating the industry are based on *the
relational data model*.  Let us review how querying is solved there.

Relational data model structures data as a collection of interrelated tables.
E.g., our sample dataset can be stored in two tables:

*Departments*

+-----------+-------------------+
| dept_id   | name              |
+===========+===================+
| dept1     | WATER MGMNT       |
+-----------+-------------------+
| dept2     | POLICE            |
+-----------+-------------------+
| dept3     | GENERAL SERVICES  |
+-----------+-------------------+
| ...       | ...               |
+-----------+-------------------+

*Employees*

+-----------+-------------------+-------------------+-------------------+-----------+-----------+
| emp_id    | name              | surname           | position          | salary    | dept_id   |
+===========+===================+===================+===================+===========+===========+
| emp1      | ALVA              | A                 | WATER RATE TAKER  | $87228.00 | dept1     |
+-----------+-------------------+-------------------+-------------------+-----------+-----------+
| emp2      | GEOFFREY          | A                 | POLICE OFFICER    | $75372.00 | dept2     |
+-----------+-------------------+-------------------+-------------------+-----------+-----------+
| emp3      | KAREN             | A                 | POLICE OFFICER    | $75372.00 | dept2     |
+-----------+-------------------+-------------------+-------------------+-----------+-----------+
| ...       | ...               | ...               | ...               | ...       | ...       |
+-----------+-------------------+-------------------+-------------------+-----------+-----------+

Relational model provides a framework for query construction called *relational
algebra*.

Operands in relational algebra are sets of homogenous tuples called
*relations*.  Any table can be seen as a relation composed of the table rows.

Operators of relational algrebra are set operations such as union,
intersection, and, most importantly, set product.  Any database query is an
expression in relational algrebra and can be written using ``SELECT`` statement
in SQL query language.

In practice, however, SQL deviates from relational algrebra quite a lot.  That
is because relational algrebra is vague on some concepts (duplicate and missing
values, aggregates) and completely ignores others (ordering of elements,
paginating).  It forced designers of SQL to introduce ad-hoc constructs for
dealing with such issues.  It is customary to blame SQL for violating sacred
rules of relational algebra, but, in fact, it must a sign that relational
algebra is not powerful enough to express transformations needed for
constructing practical queries.  Despite its real or imaginary shortcomings,
SQL continues to be *the* database query language while relational model is
seen as the only practical way to design databases.

We seek to change this balance.  We believe the functional data model, rather
than relational algebra, is a proper foundation for a database query language.
Instead of constructing queries by joining tuple sets, we should do it by
composing functions.  To justify our opinion, we design the *Rabbit* query
language.

Now is the time for bullet lists:

* *Rabbit* is as powerful as SQL; that is, it can express any query that
  can be expressed with SQL.

* *Rabbit* is significantly easier to write and comprehend than SQL, which
  makes it an ideal tool for semi-technical domain experts and other
  *accidental programmers*.

* Syntax and semantics of *Rabbit* are complete and unambiguous.  Every query
  and query fragment in *Rabbit* is a function, operators in *Rabbit* are
  function combinators.


.. rubric:: Footnotes

.. [#spivak] For an elaborate description of the functional data model in
   terms of category theory, we recommend the site of `David Spivak`_.

.. [#diagram] For mathematically minded: a schema :math:`\mathbf{S}` is a
   category generated from the schema diagram and database constraints; an
   instance :math:`I` is a functor mapping :math:`\mathbf{S}` to
   :math:`\mathbf{Set}`; a query :math:`Q: 1 \to X` is an object from
   :math:`\operatorname{Hom}_\mathbf{S}(1,-)`; the instance functor :math:`I`
   maps :math:`Q` to an element of set :math:`I(X)`.

.. _David Spivak: http://math.mit.edu/~dspivak/informatics/

