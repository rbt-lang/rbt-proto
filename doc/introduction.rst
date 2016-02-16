Introduction
============

.. slide:: Combinators
   :level: 2

   **Definition:** *Combinator* is an expression with no free variables.

   **In a broad sense:** a design technique for implementing compositional
   domain-specific languages.

   A combinatorial DSL must define:

   * *interface* for domain objects.
   * *primitives* or atomic combinators.
   * *composites* constructed from other combinators.

   Well-known examples:

   * Parser combinators (building parsers out of smaller parsers).
   * Reactive graphics (constructing objects and behavior compositionally).

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

   Constructing objects and behavior compositionally.

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

   1. Define a type that describes domain objects.
   2. Define elementary objects.
   3. Define operations to combine objects.

   **Combinators are composable.**

   Combinators with compatible interfaces could be composed in a variety of
   ways to form a composite processing pipeline.

   **Combinators are extensible.**

   A combinatorial DSL could be adapted to new domains by extending it with
   domain-specific combinators.

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

   (:math:`\operatorname{department}` maps an employee entity to the corresponding department,
   :math:`\operatorname{name}` maps a department entity to its name)

   Can use regular composition of mappings:

   .. math::

      \operatorname{department}{.}\operatorname{name}: \operatorname{Empl} \to \operatorname{Text}

   (maps an employee entity to the name of their department)


.. slide:: Querying with Rabbit: Input-Free Queries
   :level: 3

   A query is a mapping?  But I do not expect a query to have input?!

   Designate a singleton type (with a single value of this type):

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

1. The interface is a type or a type family that characterize DSL programs.
2. Primitive combinators are atomic programs, irreducible processing blocks
   from which every program must be constructed.
3. Specific rules for how programs can be combined together to form a composite
   program are prescribed by compositing combinators.

Our goal is to show a new design of a combinator-based database query language.
Before we begin, however, let us recall how combinator pattern is used in
design of two well-known examples of combinator-based DSLs: parser combinators
and composite graphics.

Let us state two properties that make combinators attractive as a design
technique for DSLs.

* **Combinators are composable.**  A DSL is fully defined by its set of
  primitives and a set of operations for composing combinators.  Any
  composition operation must be defined in a generic way so that its operands
  could be any combinators with compatible interfaces.  This property gives
  combinatorial DSLs a distinctive feel of a "construction set".

* **Combinators are extensible.**  A combinatorial DSL could be adapted to new
  domains by extending it with new primitives or composite combinators.

