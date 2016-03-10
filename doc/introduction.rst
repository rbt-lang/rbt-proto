Introduction
============

.. slide:: Combinators
   :level: 2

   **Definition:** *Combinator* is an expression with no free variables.

   **In a broad sense:** a design technique for implementing compositional
   domain-specific languages.

   A combinatorial DSL must define:

   * *interface* for domain objects.
   * *primitives* or atomic objects.
   * *composites* made of other objects.

   Well-known examples:

   * Parser combinators (building parsers out of smaller parsers).
   * Reactive graphics (constructing animation compositionally).

   We will apply this technique to *querying a database*.


.. slide:: Example: Parser Combinators
   :level: 3

   Building parsers out of smaller parsers.

   Interface (finds all prefixes matching some pattern, returns their suffixes):

   .. math::

      \operatorname{Parser} := \operatorname{Text} \to \operatorname{List}\{\operatorname{Text}\}

   Primitives (recognizes a fixed string, an empty string):

   .. math::

      \operatorname{lit}(\texttt{"goto"}),
      \quad \operatorname{eps}

   Composites (concatenation, repetition, alternative):

   .. math::

      \operatorname{cat}(p_1, p_2, \ldots), \quad
      \operatorname{rep}(p), \quad
      \operatorname{alt}(p_1, p_2, \ldots)

   Example (recognizes nested parentheses):

   .. math::

      \operatorname{parens} :=
        \operatorname{alt}(
            \operatorname{cat}(
                \operatorname{lit}(\texttt{"("}),
                \operatorname{parens},
                \operatorname{lit}(\texttt{")"}),
                \operatorname{parens}),
            \operatorname{eps})


.. slide:: Example: Reactive Graphics
   :level: 3

   Constructing graphics and behavior compositionally.

   Interface (a time-varying value):

   .. math::

      \operatorname{Signal}\{A\} := \operatorname{Time} \to A

   Primitives (constants, events, and time):

   .. math::

      \operatorname{circle} : \operatorname{Signal}\{\operatorname{Image}\}, \quad
      \operatorname{mousex} : \operatorname{Signal}\{\operatorname{Int}\}, \quad
      \operatorname{time} : \operatorname{Signal}\{\operatorname{Time}\}

   Composites (time and space transformations):

   .. math::

      \operatorname{scale}(\mathit{img},f), \quad
      \operatorname{delay}(\mathit{sig},t)

   Example (pulsating circle):

   .. math::

      \operatorname{scale}(\operatorname{circle}, \sin(\operatorname{time}))


.. slide:: Combinators: Summary
   :level: 3

   Think of combinator pattern as an extensible *"construction set"*.

   1. Define the type that describes domain objects.
   2. Define elementary objects.
   3. Define operations to combine objects.

   **Combinators are declarative.**

   * A combinator program describes *what it does*, not *how it does it*.

   * Attractive property for a DSL designed for *the accidental programmer*.

   How can we apply it to querying?


.. slide:: Querying with Rabbit: Data Model
   :level: 2

   How to apply the combinator pattern to *querying a database?*

   Start with categorical data model:

   * Objects: value and entity types.
   * Arrows: attributes and relationships.

   Example (textbook "employees & departments" schema):

   .. graphviz:: citydb-functional-data-model.dot


.. slide:: Querying with Rabbit: Queries as Combinators
   :level: 3

   **A query is a mapping:**

   .. math::

      \operatorname{Query}\{A,B\} := A \to B

   Database schema provides primitives:

   .. math::

      &\operatorname{department} & : \operatorname{Empl}&\to\operatorname{Dept} \\
      &\operatorname{name} & : \operatorname{Dept}&\to\operatorname{Text}

   * :math:`\operatorname{department}` maps an employee entity to the corresponding department;
   * :math:`\operatorname{name}` maps a department entity to its name.

   Can use regular composition of mappings:

   .. math::

      \operatorname{department}{.}\operatorname{name}: \operatorname{Empl} \to \operatorname{Text}

   * This query maps an employee entity to the name of their department.


.. slide:: Querying with Rabbit: Input-Free Queries
   :level: 3

   A query is a mapping?  But I do not expect a query to have input?!

   Designate a singleton type (with just one value):

   .. math::

      \operatorname{Void} \quad (\operatorname{nothing} \in \operatorname{Void})

   A query with no input has a type:

   .. math::

      \operatorname{Query}\{\operatorname{Void}, B\} = \operatorname{Void} \to B

   Primitive that gives a list of all employees:

   .. math::

      \operatorname{employee} : \operatorname{Void} \to \operatorname{Seq}\{\operatorname{Empl}\}


.. slide:: Querying with Rabbit: Example
   :level: 3

   *Find the total number of employees.*

   Start with the primitive that gives a list of all employees:

   .. math::

      \operatorname{employee} : \operatorname{Void} \to \operatorname{Seq}\{\operatorname{Empl}\}

   Use a generic aggregate combinator:

   .. math::

      \operatorname{count} : (A \to \operatorname{Seq}\{B\}) \to (A \to \operatorname{Int})

   The total number of employees:

   .. math::

      \operatorname{count}(\operatorname{employee}) : \operatorname{Void} \to \operatorname{Int}


.. slide:: Query Combinators and Relational Algebra
   :level: 2

   Compare with relational algebra:

   * Interface: a set of tuples.
   * Primitives: tables.
   * Composites: set operations.

   Rabbit has richer primitives.  Its first-class objects are not just tables
   (as in SQL):

   .. math::

      \operatorname{employee} : \operatorname{Void} \to \operatorname{Seq}\{\operatorname{Empl}\}

   But also attributes and relationships (not so in SQL):

   .. math::

      &\operatorname{department} & : \operatorname{Empl}&\to\operatorname{Dept} \\
      &\operatorname{name} & : \operatorname{Dept}&\to\operatorname{Text}

   Richer primitives (and special scoping rules) make variables unnecessary.
   Expressions in Rabbit are *combinators* in the narrow sense.


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


.. slide:: References and Related Works
   :level: 2

   * Combinators (Curry); Parser combinators; Reactive graphics (Elliott); KOLA (Cherniack).

   * Functional data model; Categorical databases, monads (Spivak).

   * Synchronization trees (Milner).

   * Network data model (Bachman); SEQUEL (Chamberlin, Boyce).

   * XPath (Clark).

   * Julia programming language.

   * Our work on YAML, HTSQL.


In this section, we review the combinator pattern and how it is used in design
of declarative domain-specific languages.  Then we show how combinators can be
applied to prototype a database query language.


Combinator pattern
------------------

In computer science, the term *combinator* is used in a narrow and a broad
sense.  In a narrow definition, a combinator is any expression with no free
variables.  That is to say, a combinator expression has its value completely
determined by its structure.

In a broad sense, *combinator pattern* is a technique for designing
domain-specific languages (DSLs), which prescribes us to model programs in
terms of self-contained composable processing blocks.  These blocks should
either come from a set of predefined atomic *primitives* or be constructed from
other blocks as *composites*.  Operations that combine blocks to make composite
blocks are often called combinators, which gave the name to the technique, but
it is the fact that that every block is self-contained that connects this usage
of the term with the narrow definition.  Going forward, we will refer to
individual blocks as well as the operations that combine them as combinators.

A combinator-based DSL is defined by its three constituents: interface,
primitives and composites.

1. The interface is a type or a type family that characterizes DSL programs.
2. Primitive combinators are atomic programs, irreducible processing blocks
   from which every program must be constructed.
3. Specific rules for how programs can be combined together to form a composite
   program are prescribed by compositing combinators.

Our goal is to show a new design of a combinator-based database query language.
Before we begin, however, let us recall how combinator pattern is used in
design of two well-known combinator-based DSLs: parser combinators and reactive
animation.  Reviewing these familiar examples will let us highlight the roles
of different aspects of this design pattern.

We start with parser combinators, a method for building a parsing framework.  A
parser, in its simplest form, is a program that recognizes when the input
string matches a certain pattern.  This immediately suggests an interface:

.. math::

   \operatorname{Parser} := \operatorname{String} \to \operatorname{Bool}

But this signature does not show a clear way to compose several parsers
together aside from using simple ``and`` or ``or`` operators.  This is not
enough to make interesting parsers.  We need to expand the parser interface to
provide some hooks by which two parsers could be chained together.

We make the interface composable by having a parser emit not a boolean value,
but a list of strings.  Specifically, our parser recognizes all *prefixes* of
the input string that match a certain pattern, and returns a list of the
respective *suffixes*.  Thus, when the parser does not recognize the input
string or any of its prefixes, it returns an empty list.  When the parser
recognizes the whole string, but not any if its prefixes, it returns a list
with one element, an empty string.

Here is the updated parser interface:

.. math::

   \operatorname{Parser} := \operatorname{String} \to \operatorname{Vector}\{\operatorname{String}\}

For primitive parsers, we take a parser :math:`\operatorname{lit}(c)` that
recognizes a fixed character :math:`c` and a parser
:math:`\operatorname{empty}` that recognizes an empty string.

.. math::

   & \operatorname{lit}(\texttt{'s'}) : \texttt{"sql"} \mapsto [\texttt{"ql"}] \\
   & \operatorname{lit}(\texttt{'s'}) : \texttt{"rabbit"} \mapsto []

.. math::

   \operatorname{empty} : \texttt{"rabbit"} \mapsto [\texttt{"rabbit"}]

As for composition operations, we only need two.  Combinator
:math:`\operatorname{alt}(p_1,p_2,\ldots,p_n)` recognizes a string when it is
recognized by any of the parsers :math:`p_1,p_2,\ldots,p_n`.  Combinator
:math:`\operatorname{cat}(p_1,p_2,\ldots,p_n)` chains the parsers
:math:`p_1,p_2,\ldots,p_n` in a series; it recognizes such a string that could
be broken into :math:`n` substrings, each recognized by the corresponding
parser in :math:`p_1,p_2,\ldots,p_n`.

Here is an illustration:

.. math::

   & \operatorname{alt}(
        \operatorname{lit}(\texttt{'s'}),
        \operatorname{lit}(\texttt{'q'}),
        \operatorname{lit}(\texttt{'l'}))
        : \texttt{"sql"} \mapsto [\texttt{"ql"}] \\
   & \operatorname{cat}(
        \operatorname{lit}(\texttt{'s'}),
        \operatorname{lit}(\texttt{'q'}),
        \operatorname{lit}(\texttt{'l'}))
        : \texttt{"sql"} \mapsto [\texttt{""}]

We omit the implementation of these combinators, but we must note that while
the the :math:`\operatorname{alt}` combinator can be implemented with the
parser interface defined as :math:`\operatorname{String} \to
\operatorname{Bool}`, the :math:`\operatorname{cat}` combinator cannot.  It is
remarkable how a richer interface enables more interesting operations.

Amazingly, these two primitives and two composites are all that is needed to
express quite sophisticated parsers.  Indeed, a parser for a context-free
language can be constructed by transcribing its formal grammar.  For example,
consider a production rule for a string of well-formed parentheses:

.. math::

   \mathit{parens} ::=
        \texttt{'('}\;
        \mathit{parens}\;
        \texttt{')'}\;
        \mathit{parens}\;|\;
        \epsilon

It can be directly converted to a parser:

.. code-block:: julia

    parens() = alt(cat(lit('('), parens, lit(')'), parens), empty)

This definition can be mistaken for a formal grammar, but it is, in fact, an
executable program.  One of the attractive features of combinator-based DSLs is
that the program code mirrors the program specification.

Let us complement the review of parser combinators with an example of a
combinator-based DSL for interactive graphics, known as *reactive animation*.
It will be instructive to see how reactive animation materializes such an
abstract concept as behavior and how it makes possible to construct behavior
compositionally.  As before, we will review three components of the DSL:
interface, primitives and composites.

Animation is an image changing in time, which can be described as a function
:math:`\operatorname{Time}\to\operatorname{Image}`.  Image parameters such as
color, position and size may, too, vary in time.  Time-varying values of
different types can be modeled with a parametric interface:

.. math::

   \operatorname{Signal}\{A\} := \operatorname{Time} \to A

What signals could be taken for primitives?  All primitive signals could be
divided on three classes.  First, any scalar value could be regarded as a
constant signal.  This includes numbers, text values and basic graphics shapes:

.. math::
   :nowrap:

   \begin{alignat*}{2}
   & 1 & \;:\; & \operatorname{Signal}\{\operatorname{Int}\} \\
   & \texttt{"sql"} & \;:\; & \operatorname{Signal}\{\operatorname{String}\} \\
   & \operatorname{circle} & \;:\; & \operatorname{Signal}\{\operatorname{Image}\}
   \end{alignat*}

Another class of primitives contains just one signal, the identity function on
the time domain:

.. math::

   & \operatorname{time} : \operatorname{Time} \to \operatorname{Time} \\
   & \operatorname{time} : t \mapsto t

The last class of primitive signals describe external events:

.. math::

   \operatorname{mousex},\operatorname{mousey} : \operatorname{Signal}\{\operatorname{Int}\}

What about composites?  Just like a scalar value could be lifted to a constant
signal, a regular function could be lifted to a time-invariant signal
combinator.  For example, a scalar function :math:`\sin(t)` becomes a
combinator:

.. math::

   & \sin : \operatorname{Signal}\{\operatorname{Float}\}
        \to \operatorname{Signal}\{\operatorname{Float}\} \\
   & \sin(x) : t \mapsto \sin(x(t))

This way we can get a large number of combinators operating on signals:

.. math::

   (x + y), \quad
   \operatorname{scale}(i,f), \quad
   \operatorname{move}(i,x,y)

Other signal combinators operate on time explicitly.  Consider, for example, the
:math:`\operatorname{delay}(x,T)` combinator, which delays the
incoming signal :math:`x` for time :math:`T`.  It can be defined by

.. math::

   & \operatorname{delay} :
        (\operatorname{Signal}\{A\}, \operatorname{Signal}\{\operatorname{Float}\}) \to
        \operatorname{Signal}\{A\} \\
   & \operatorname{delay}(x,T) : t \mapsto x(t-T(t))

Finally, let us show some simple examples.

A periodic signal:

.. math::

   \sin(2\pi\cdot\operatorname{time})

A pulsating circle:

.. math::

   \operatorname{scale}(\operatorname{circle}, \sin(\operatorname{time}))

A circle on an orbit:

.. math::

   \operatorname{move}(\operatorname{circle}, \sin(\operatorname{time}), \sin(\operatorname{time}+\pi))

An image that follows the mouse cursor:

.. math::

   \operatorname{move}(\operatorname{circle}, \operatorname{mousex}, \operatorname{mousey})

It is tempting to continue with more examples, including ones with real
interactivity (the "reactive" part of the DSL), but let us stop at this point
and instead ask ourselves what makes these examples so compelling.

They are remarkably succinct, but it is only a part of the appeal.  More
importantly, the example programs have the structure that reflects what the
programs do while leaving out how they do it.  Such programming style is called
*declarative*.

An imperative program is a series of steps that must be executed consecutively
to obtain the result.  By contrast, a declarative program is a statement that
describes the result without explicitly enumerating the steps to achieve it.
This is an desirable property for a DSL, especially the one intended for
semi-technical domain experts.

As we design a database query language, we see our users among *accidental
programmers*, professionals and data experts who are not software engineers by
trade, but who must write database queries or data processing code to get
things done.  For them, a natural way to express their problems is provided by
declarative programming with combinators.


Querying with combinators
-------------------------

The combinator pattern gives us a roadmap for a design of a database query
language:

1. Define the query interface.
2. Describe the set of primitive queries.
3. Describe operations (combinators) for making composite queries.

A query pulls data from a database, so before we can define what a query is, we
need to understand how data is structured by the database.  Undestanding of a
database structure requires three concepts: database model, database schema and
database instance.

A database model is a set of rules for describing database structure.  In this
document, we will refer to three models: relational, hierarchical and
categorical.  The structure of a particular database is called its schema and a
snapshot of its content is called its instance.

As a starting point, we use the categorical database model.  In this model,
database schema is represented as a directed graph with nodes and arcs of the
graph specifying how data is structured in the database.  Namely, the nodes
correspond to types of entities and types of attribute values; the arcs
correspond to entity attributes and relationships between entities.  A database
instance represents data by mapping the nodes and the arcs of the schema graph
to sets (of entities or values) and functions on sets (that map entities to
attribute values or related entities).

Let us demonstrate this model on a textbook example of a "departments &
employees" database schema.

.. graphviz:: citydb-functional-data-model.dot

The schema graph contains four nodes; two of them represent a class of
department entities and a class of employee entities:

.. math::

   \operatorname{Dept}, \qquad \operatorname{Empl}

The other two represent the type of text values and the type of integer values:

.. math::

   \operatorname{Text}, \qquad \operatorname{Int}

An arc of the schema graph connecting two entity classes represents a
relationship between entities of these classes.  An arc connecting an entity
class to a value type corresponds to an entity attribute.  In this schema, we
see a text attribute of the department entity:

.. math::

    \operatorname{name} : \operatorname{Dept} \to \operatorname{Text}

a collection of attributes of the employee entity:

.. math::
   :nowrap:

   \begin{alignat*}{2}
   & \operatorname{name} & \;:\; & \operatorname{Empl} \to \operatorname{Text} \\
   & \operatorname{surname} & \;:\; & \operatorname{Empl} \to \operatorname{Text} \\
   & \operatorname{position} & \;:\; & \operatorname{Empl} \to \operatorname{Text} \\
   & \operatorname{salary} & \;:\; & \operatorname{Empl} \to \operatorname{Int} \\
   \end{alignat*}

and a relationship that maps each employee to the respective department:

.. math::

   \operatorname{department}: \operatorname{Empl} \to \operatorname{Dept}

Now, we have enough to define the query interface:

.. math:: \operatorname{Query}\{A,B\} := A \to B

Here, each of the parameters :math:`A` and :math:`B` is either a value type or
an entity class.

This definition immediately gives us a set of primitives and one composition
operation.  Indeed, each arc of the schema graph becomes a primitive query,
and, given two queries with compatible inputs and outputs,

.. math::

   f: A \to B, \qquad
   g: B \to C

we can combine then using function composition:

.. math::

   &f{.}g : A \to C \\
   &f{.}g : a \mapsto g(f(a))

Let us demonstrate this operation on the sample schema.  We take two primitive
queries, :math:`\operatorname{department}`, which maps any employee entity to
the respective department, and :math:`\operatorname{name}`, which maps a
department entity to the department name:

.. math::
   :nowrap:

   \begin{alignat*}{3}
   & \operatorname{department} &\;:\;& \operatorname{Empl} &\;\to\;& \operatorname{Dept} \\
   & \operatorname{name} &\;:\;& \operatorname{Dept} &\;\to\;& \operatorname{Text}
   \end{alignat*}

The composition :math:`\operatorname{department}.\operatorname{name}` of these
two queries maps an employee entity to the name of their department:

.. math::

   \operatorname{department}{.}\operatorname{name}: \operatorname{Empl} \to \operatorname{Text}

Our definition of the query interface may seem unusual.  It appears that to get
any output from a query, we need to supply it with some input, which does not
match the conventional notion of a database query that runs and produces a
result with no input required.  We did construct a query that finds *the name
of the department given an employee*, but can we express a query that finds
*the total number of employees*?

To reconcile the query interface with the conventional notion of a database
query, we introduce a designated singleton type :math:`\operatorname{Void}`,
which contains exactly one value
:math:`\operatorname{nothing}\in\operatorname{Void}`.  Then a query with no
input can be expressed as a mapping from the :math:`\operatorname{Void}` type.
The query result can be obtained by submitting the value
:math:`\operatorname{nothing}` for the query input.

For example, let us build a query that finds *the total number of employees*.
We can already guess the signature of this query:

.. math:: \operatorname{Void} \to \operatorname{Int}

We start with a new primitive, :math:`\operatorname{employee}`, which
produces a sequence of all employee entities:

.. math::

   & \operatorname{employee} : \operatorname{Void}
        \to \operatorname{Seq}\{\operatorname{Empl}\} \\
   & \operatorname{employee} : \operatorname{nothing} \mapsto
        [e_1, e_2, \ldots]

Here, :math:`\operatorname{Seq}\{A\}` is a parametric sequence type, which
is used when a query produces a sequence of values.

To count the number of employees, we will use combinator
:math:`\operatorname{count}`, which has the following signature:

.. math::

   \operatorname{count} : (A \to \operatorname{Seq}\{B\}) \to (A \to \operatorname{Int})

The signature indicates that :math:`\operatorname{count}` transforms any
sequence-valued query to an integer-valued query, that is,
:math:`\operatorname{count}(Q)` returns the number of elements produced by the
query :math:`Q`.

Applying :math:`\operatorname{count}` to :math:`\operatorname{employee}`, we
get the query that counts the total number of employees:

.. math::

   \operatorname{count}(\operatorname{employee}) : \operatorname{Void}
        \to \operatorname{Int}


Related works and references
----------------------------

We will continue developing the query language in later chapters, but for now, let
us review the present query model compares with the most popular query language,
SQL, and the underlying theory of relational algebra.

How is it different from relational algebra?  Let us consider the query language,
primitives and composite operations that are provided by relational algebra.

1. In relational algebra, a query is a table, or a set of tuples.
2. Primitives queries are tables containing all records for a fixed class
   of entities, e.g., a table of all employees or a table of all departments.
3. Compositing operations are set product and other set operations.

Let us note one major difference between relational algebra and combinator-based
approach.  In relational algebra, entity attributes and relationships between
entities are not first-class objects, in Rabbit, they are.  That's the reason
why combinator pattern works, we do not need a variable ranging over some
entities of a particular type.

Still SQL has been holding the position of the most popular query language
since 1970s.  What makes Rabbit an attractive alternative?

The fact that Rabbit queries are composable and declarative has the following
implications:

* Queries are easier to write.  Combinators allows one to compose a query
  as a pipeline of data operations.
* Equally, or perhaps more importantly, unfamiliar queries are easier to read.
  In order to understand a query, is has to be decomposed into components
  each of which could be analyzed independently.

