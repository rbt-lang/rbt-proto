Combinator Pattern
==================


.. slide:: Combinator Pattern
   :level: 2

   **Rabbit** is a database query language.

   It is based on a DSL design technique called *combinator pattern:*

   1. Define the type of domain objects, *the interface.*
   2. Define atomic objects, so called *primitives.*
   3. Define operations for combining objects, which we call *composites.*

   In examples, we assume a textbook "departments & employees" schema.


.. slide:: The Interface
   :level: 2

   The interface describes domain objects.  Hence it must answer the question:

   * *What is a database query?*

   Let us look at some examples:

   :math:`Q_1`. *Show the total number of departments.*

   :math:`Q_2`. *For every department, show its name and the number of
   employees.*

   Formally, the interface is a type (possibly parametric):

   .. math:: \operatorname{Query}\{?\} :=\; ?

   Can we guess the type of the queries :math:`Q_1` and :math:`Q_2`?


.. slide:: The Interface: Type Catalogue
   :level: 3

   We have a number of types at our disposal:

   1. The singleton type: :math:`\operatorname{Void}`.

   2. Value types, shared by all schemas:

      .. math::

         \operatorname{Bool},\; \operatorname{Int},\; \operatorname{Text},\;
         \operatorname{Date},\; \ldots

   3. Entity types, specific to each schema:

      .. math::

         \operatorname{Dept},\; \operatorname{Empl}

   3. Parametric types:

      .. math::

         \operatorname{Opt}\{T\},\; \operatorname{Seq}\{T\},\;
         \operatorname{Tuple}\{T_1,T_2,\ldots\},\;
         \operatorname{Union}\{T_1,T_2,\ldots\},\; \ldots


.. slide:: The Interface: Query Output
   :level: 3

   What type can we assign to the examples?

   :math:`Q_1`. *Show the total number of departments.*

   :math:`Q_2`. *For every department, show its name and the number of
   employees.*

   Perhaps, it's the type of the query output?

   .. math::

      Q_1 : \operatorname{Int}, \quad
      Q_2 : \operatorname{Seq}\{\operatorname{Tuple}\{\operatorname{Text},\operatorname{Int}\}\}\;?

   * Good: describes what the query produces.

   * But too inflexible: no obvious way to combine different queries.


.. slide:: The Interface: Query Input
   :level: 3

   The idea: let queries accept *input*.

   So, in addition to regular queries:

   :math:`Q_1`. *Show the total number of departments.*

   :math:`Q_2`. *For every department, show its name and the number of
   employees.*

   We also permit "queries" with input:

   :math:`Q_3`. *For a given department, get the number of employees.*

   We see a hint of composability: :math:`Q_3` must be a part of :math:`Q_2`.
   But:

   * The input of :math:`Q_3` is :math:`\operatorname{Dept}`.
   * What is the input of :math:`Q_1` and :math:`Q_2`?


.. slide:: The Interface: Queries without Input
   :level: 3

   Your typical database query has no input:

   :math:`Q_1`. *Show the total number of departments.*

   :math:`Q_2`. *For every department, show its name and the number of
   employees.*

   And yet we'd like to make query input a part of its interface.

   Here's the trick:

   * For a query without input, declare its input type as
     :math:`\operatorname{Void}`.

   * :math:`\operatorname{Void}` is a singleton type, with only one value.

   * No discretion in choosing the input value is the same as no input!


.. slide:: The Interface: Definition and Examples
   :level: 3

   Define query interface as a mapping from query input to query output.

   .. math::

      \operatorname{Query}\{A,B\} := A \to B

   Examples:

   :math:`Q_1`. *Show the total number of departments.*

   .. math::

      Q_1 : \operatorname{Void}\to\operatorname{Int}

   :math:`Q_2`. *For every department, show its name and the number of
   employees.*

   .. math::

      Q_2 : \operatorname{Void}\to\operatorname{Seq}\{\operatorname{Tuple}\{\operatorname{Text},\operatorname{Int}\}\}

   :math:`Q_3`. *For a given department, get the number of employees.*

   .. math::

      Q_3 : \operatorname{Dept}\to\operatorname{Int}


.. slide:: The Interface: Components
   :level: 3

   Let us enumerate the components of query inteface:

   * Input domain.
   * Basic output domain.
   * Output (monadic) structure:

     - *plain:* exactly one output value for each input;
     - *partial:* no output or one output value;
     - *plural:* zero, one or more output values.

   Example:
   :math:`Q_2 : \operatorname{Void}\to\operatorname{Seq}\{\operatorname{Tuple}\{\operatorname{Text},\operatorname{Int}\}\}`.

   * Input domain: :math:`\operatorname{Void}`.
   * Output domain: :math:`\operatorname{Tuple}\{\operatorname{Text},\operatorname{Int}\}`.
   * Output structure: *plural*.


.. slide:: The Interface: Foreshadowing
   :level: 3

   Inteface components:

   * Input domain.
   * Basic output domain.
   * Output structure: plain, partial, plural.

   Later, we will clarify and extend the interface:

   * Clarify output structure:

     - *at least one* output value;
     - *unique* values.

   * Structure for input:

     - *parameters;*
     - *past* and *future* values.


.. slide:: Primitives
   :level: 2

   Combinator pattern: interface, primitives, composites.

   1. We defined query interface: *a mapping from query input to query output:*

      .. math::

         \operatorname{Query}\{A,B\} := A \to B

   2. Next step: define atomic or *primitive* queries.

      We can get many primitives from the database schema:

      * *Classes.*
      * *Attributes.*
      * *Links.*

      Some primitives are schema-independent:

      * *Constants.*
      * *Identity.*


.. slide:: Primitives: Classes
   :level: 3

   A database describes some material or abstract entities.

   * All entities of the same type form a *class:*

     * class of all departments,
     * class of all employees,
     * etc.

   *Class primitive:* produces *all* entities of a specific class.

   Examples:

   .. math::

      &\operatorname{department} & : \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Dept}\} \\
      &\operatorname{employee} & : \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Empl}\}


.. slide:: Primitives: Attributes
   :level: 3

   We cannot observe an entity directly.  Instead, all we can learn about it is:

   * its attributes;
   * its relationships with other entities.

   *Attribute primitive:* maps an entity to the value of its attribute.

   Each entity class has its own fixed set of attributes.  Examples:

   .. math::

      &\operatorname{name} & : \operatorname{Dept}&\to\operatorname{Text} \\
      &\operatorname{name} & : \operatorname{Empl}&\to\operatorname{Text} \\
      &\operatorname{surname} & : \operatorname{Empl}&\to\operatorname{Text} \\
      &\operatorname{position} & : \operatorname{Empl}&\to\operatorname{Text} \\
      &\operatorname{salary} & : \operatorname{Empl}&\to\operatorname{Int}


.. slide:: Primitives: Links
   :level: 3

   Entities may be in complex relationships with each other.

   *Link primitive:* maps an entity to the related entity or entities.

   * For each kind of relationship, we introduce a link primitive.

   * In fact, *two* links: one in each direction.

   Examples:

   .. math::

      &\operatorname{employee} & : \operatorname{Dept}&\to\operatorname{Seq}\{\operatorname{Empl}\} \\
      &\operatorname{department} & : \operatorname{Empl}&\to\operatorname{Dept} \\
      &\operatorname{manages} & : \operatorname{Empl}&\to\operatorname{Seq}\{\operatorname{Empl}\} \\
      &\operatorname{managed\_by} & : \operatorname{Empl}&\to\operatorname{Opt}\{\operatorname{Empl}\}


.. slide:: Primitives: Homonyms
   :level: 3

   We introduced different primitives with the same name!

   .. math::

      &\operatorname{department} & : \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Dept}\} \\
      &\operatorname{department} & : \operatorname{Empl}&\to\operatorname{Dept} \\
      &\operatorname{employee} & : \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Empl}\} \\
      &\operatorname{employee} & : \operatorname{Dept}&\to\operatorname{Seq}\{\operatorname{Empl}\} \\
      &\operatorname{name} & : \operatorname{Dept}&\to\operatorname{Text} \\
      &\operatorname{name} & : \operatorname{Empl}&\to\operatorname{Text}

   * But they have different inputs, so we can identify them unambiguously.

   * Within one class, all attributes and links must have a unique name.


.. slide:: Primitives: Constants
   :level: 3

   Any language needs constants:

   .. math::

      \operatorname{true},\; 1024,\; \texttt{"Rabbit"}

   In Rabbit, constants are primitive queries.

   *Constant primitive:* maps any input to a fixed value.

   * Query output: the type of the constant value.

   * Query input?  Could be anything; constants are *polymorphic* in their input.

   .. math::

      &\operatorname{true} & : A&\to\operatorname{Bool} \\
      &1024 & : A&\to\operatorname{Int} \\
      &\texttt{"Rabbit"} & : A&\to\operatorname{Text}


.. slide:: Primitives: :math:`\operatorname{null}` and :math:`\operatorname{here}`
   :level: 3

   There is a special constant that indicates lack of any value.

   *Null primitive:* has no output.

   .. math::

      \operatorname{null} : A \to \operatorname{Opt}\{\operatorname{Union}\{\}\}

   Our last primitive: the *identity* function.

   *Identity primitive:* maps any value to itself.

   .. math::

      \operatorname{here} : A \to A


.. slide:: Composites
   :level: 2

   Combinator pattern so far:

   1. Query interface: a mapping from query input to query output.

   2. Primitive queries:

      * classes, attributes and links;
      * constants and identity.

   What is left?

   3. *Query combinators* for constructing new queries.

   A query combinator is a function that:

   * takes one or more queries as input;
   * produces a new query as output.

   Here, we will introduce just one combinator: *query composition.*


.. slide:: Functional Composition
   :level: 3

   For any functions:

   .. math::

      f : A \to B, \quad g : B \to C

   We denote *composition* of :math:`f` and :math:`g` by:

   .. math::

      f{.}g : A \to C


   Functions :math:`f : A \to B` and :math:`g : B \to C` are *composable*
   because:

   * They share the intermediate domain: :math:`B`.

   Queries are mappings, so can we compose them?


.. slide:: Composition Combinator
   :level: 3

   Composition is a binary query combinator!

   For example, take two primitive queries:

   .. math::

      &\operatorname{department} & : \operatorname{Empl}&\to\operatorname{Dept}, \quad
      &\operatorname{name} & : \operatorname{Dept}&\to\operatorname{Text}

   Composing them, we get a new query:

   .. math::

      \operatorname{department}{.}\operatorname{name}: \operatorname{Empl} \to \operatorname{Text}

   Prerequisite: the queries must share the intermediate domain.

   * In practice, this is too restrictive.

   * Can we relax this requirement?


.. slide:: Imperfect Composition
   :level: 3

   Often, queries do not perfectly agree on the intermediate domain.

   Example:

   .. math::

      &\operatorname{employee} & : \operatorname{Dept}&\to\operatorname{Seq}\{\operatorname{Empl}\} \\
      &\operatorname{name} & : \operatorname{Empl}&\to\operatorname{Text}

   Example:

   .. math::

      &\operatorname{managed\_by} & : \operatorname{Empl}&\to\operatorname{Opt}\{\operatorname{Empl}\} \\
      &\operatorname{salary} & : \operatorname{Empl}&\to\operatorname{Int}

   We still want to compose them!


.. slide:: Natural Embedding and Monadic Composition
   :level: 3

   Query composition :math:`Q{.}R` is defined as a combination of two rules:

   1. Natural embedding that lifts both queries to the common monadic structure.

      .. math::

         T \hookrightarrow \operatorname{Opt}\{T\} \hookrightarrow \operatorname{Seq}\{T\}


   2. Monadic composition for :math:`\operatorname{Opt}\{T\}` and
      :math:`\operatorname{Seq}\{T\}`.

      +--------------------------------------------------+--------------------------------------------------+--------------------------------------------------+
      | :math:`Q`                                        | :math:`R`                                        | :math:`Q{.}R`                                    |
      +==================================================+==================================================+==================================================+
      | :math:`A \to \operatorname{Opt}\{B\}`            | :math:`B \to \operatorname{Opt}\{C\}`            | :math:`A \to \operatorname{Opt}\{C\}`            |
      +--------------------------------------------------+--------------------------------------------------+--------------------------------------------------+
      | :math:`A \to \operatorname{Seq}\{B\}`            | :math:`B \to \operatorname{Seq}\{C\}`            | :math:`A \to \operatorname{Seq}\{C\}`            |
      +--------------------------------------------------+--------------------------------------------------+--------------------------------------------------+


.. slide:: Composition: Example
   :level: 3

   Let us compose two primitive queries:

   .. math::

      &\operatorname{managed\_by} & : \operatorname{Empl}&\to\operatorname{Opt}\{\operatorname{Empl}\} \\
      &\operatorname{salary} & : \operatorname{Empl}&\to\operatorname{Int}

   1. Lift the output of :math:`\operatorname{salary}` to
      :math:`\operatorname{Opt}\{\operatorname{Int}\}`:

      .. math::

         \operatorname{Empl}\overset{\operatorname{salary}}{\longrightarrow}\operatorname{Int}
         \hookrightarrow\operatorname{Opt}\{\operatorname{Int}\}

   2. Use monadic composition for :math:`\operatorname{Opt}\{T\}`.  We get:

      .. math::

         \operatorname{managed\_by}{.}\operatorname{salary} :
         \operatorname{Empl} \to \operatorname{Opt}\{\operatorname{Int}\}

   This query produces, for a given employee, the salary of their manager.


.. slide:: Composition Rules (1 of 3)
   :level: 3

   We can summarize query composition rules in the following table:

   +--------------------------------------------------+--------------------------------------------------+--------------------------------------------------+
   | :math:`Q`                                        | :math:`R`                                        | :math:`Q{.}R`                                    |
   +==================================================+==================================================+==================================================+
   | :math:`A \to B`                                  | :math:`B \to C`                                  | :math:`A \to C`                                  |
   +--------------------------------------------------+--------------------------------------------------+--------------------------------------------------+
   | :math:`A \to B`                                  | :math:`B \to \operatorname{Opt}\{C\}`            | :math:`A \to \operatorname{Opt}\{C\}`            |
   +--------------------------------------------------+--------------------------------------------------+--------------------------------------------------+
   | :math:`A \to B`                                  | :math:`B \to \operatorname{Seq}\{C\}`            | :math:`A \to \operatorname{Seq}\{C\}`            |
   +--------------------------------------------------+--------------------------------------------------+--------------------------------------------------+


.. slide:: Composition Rules (2 of 3)
   :level: 3

   We can summarize query composition rules in the following table:

   +--------------------------------------------------+--------------------------------------------------+--------------------------------------------------+
   | :math:`Q`                                        | :math:`R`                                        | :math:`Q{.}R`                                    |
   +==================================================+==================================================+==================================================+
   | :math:`A \to \operatorname{Opt}\{B\}`            | :math:`B \to C`                                  | :math:`A \to \operatorname{Opt}\{C\}`            |
   +--------------------------------------------------+--------------------------------------------------+--------------------------------------------------+
   | :math:`A \to \operatorname{Opt}\{B\}`            | :math:`B \to \operatorname{Opt}\{C\}`            | :math:`A \to \operatorname{Opt}\{C\}`            |
   +--------------------------------------------------+--------------------------------------------------+--------------------------------------------------+
   | :math:`A \to \operatorname{Opt}\{B\}`            | :math:`B \to \operatorname{Seq}\{C\}`            | :math:`A \to \operatorname{Seq}\{C\}`            |
   +--------------------------------------------------+--------------------------------------------------+--------------------------------------------------+


.. slide:: Composition Rules (3 of 3)
   :level: 3

   We can summarize query composition rules in the following table:

   +--------------------------------------------------+--------------------------------------------------+--------------------------------------------------+
   | :math:`Q`                                        | :math:`R`                                        | :math:`Q{.}R`                                    |
   +==================================================+==================================================+==================================================+
   | :math:`A \to \operatorname{Seq}\{B\}`            | :math:`B \to C`                                  | :math:`A \to \operatorname{Seq}\{C\}`            |
   +--------------------------------------------------+--------------------------------------------------+--------------------------------------------------+
   | :math:`A \to \operatorname{Seq}\{B\}`            | :math:`B \to \operatorname{Opt}\{C\}`            | :math:`A \to \operatorname{Seq}\{C\}`            |
   +--------------------------------------------------+--------------------------------------------------+--------------------------------------------------+
   | :math:`A \to \operatorname{Seq}\{B\}`            | :math:`B \to \operatorname{Seq}\{C\}`            | :math:`A \to \operatorname{Seq}\{C\}`            |
   +--------------------------------------------------+--------------------------------------------------+--------------------------------------------------+


.. slide:: Composition: Associativity
   :level: 3

   Important property: composition of functions is associative.

   Take:

   .. math::

      f : A \to B, \quad g : B \to C, \quad h : C \to D

   Then:

   .. math::

      (f{.}g){.}h = f{.}(g{.}h) = f{.}g{.}h

   * This also holds for imperfect composition of queries.

   * Allows us to write composition chain without parentheses.

   Example:

   .. math::

         \operatorname{employee}{.}\operatorname{managed\_by}{.}\operatorname{salary} :
         \operatorname{Void} \to \operatorname{Seq}\{\operatorname{Int}\}


.. slide:: Conclusion
   :level: 2

   Combinator pattern:

   1. Query interface: a mapping from query input to query output.

   2. Primitive queries:

      * classes, attributes and links;
      * constants and identity.

   3. Query combinators:

      * query composition.
      * ...?

   Many more query combinators in the next sections.


