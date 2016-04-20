Query Combinators
=================


.. slide:: Query Combinators
   :level: 2

   We use *combinator pattern* to design a database query language:

   1. Define the type of domain objects, *the interface.*
   2. Define atomic objects, so called *primitives.*
   3. Define operations for combining objects, which we call *composites.*

   We call it the **Rabbit** query language.

   In examples, we assume a textbook "departments & employees" schema.


.. slide:: The Interface
   :level: 2

   The interface must answer to the question:

   * *What is a database query?*

   Examples of queries:

   :math:`Q_1`. *Show the total number of departments.*

   :math:`Q_2`. *For every department, show its name and the number of
   employees.*

   Formally, we need to define a (possibly parametric) type

   .. math:: \operatorname{Query} :=\; ?

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

   Let us guess the interface of the examples:

   :math:`Q_1`. *Show the total number of departments.*

   :math:`Q_2`. *For every department, show its name and the number of
   employees.*

   Can we define the query interface as the type of the query output?

   .. math::

      Q_1 : \operatorname{Int}, \quad
      Q_2 : \operatorname{Seq}\{\operatorname{Tuple}\{\operatorname{Text},\operatorname{Int}\}\}\;?

   * Good: describes what the query produces.

   * But too inflexible: no obvious way to combine different queries.


.. slide:: The Interface: Query Input
   :level: 3

   Here is the idea: allow queries to accept *input*.

   So in addition to these two examples:

   :math:`Q_1`. *Show the total number of departments.*

   :math:`Q_2`. *For every department, show its name and the number of
   employees.*

   The following is also a "query":

   :math:`Q_3`. *For a given department, get the number of employees.*

   This suggests composability: :math:`Q_3` must be a part of :math:`Q_2`.

   * The input of :math:`Q_3` is :math:`\operatorname{Dept}`.
   * What is the input of :math:`Q_1` and :math:`Q_2`?


.. slide:: The Interface: Queries without Input
   :level: 3

   Most queries do not have any input:

   :math:`Q_1`. *Show the total number of departments.*

   :math:`Q_2`. *For every department, show its name and the number of
   employees.*

   And yet we'd like to make query input a part of its interface.

   * A trick: for queries without input, declare their input type as
     :math:`\operatorname{Void}`.

   * :math:`\operatorname{Void}` is a singleton type, with only one value.

   * No discretion in choosing the input value is the same as lack of input!


.. slide:: The Interface: Conclusion and Examples
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


.. slide:: Primitives
   :level: 2

   We defined query interface: *a mapping from query input to query output:*

   .. math::

      \operatorname{Query}\{A,B\} := A \to B

   Next step: define atomic or *primitive* queries.

   We can get many primitives from the database schema:

   * *Classes.*
   * *Attributes.*
   * *Links.*

   Some primitives are schema-independent:

   * *Constants.*
   * *Identity.*


.. slide:: Primitives: Classes
   :level: 3

   * Each database describes some material or abstract entities.

   * All entities of the same type form a *class:*

     * class of all departments,
     * class of all employees,
     * etc.

   A class primitive produces *all* entities of a specific class.

   Examples:

   .. math::

      &\operatorname{department} & : \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Dept}\} \\
      &\operatorname{employee} & : \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Empl}\}


.. slide:: Primitives: Attributes
   :level: 3

   We cannot observe an entity directly.  Instead, all we can learn about it is:

   * its attributes;
   * its relationships with other entities.

   An attribute primitive maps an entity to the value of its attribute.

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

   For each kind of relationship, we introduce a link primitive.

   A link primitive maps an entity to the related entity or entities.

   In fact, for each relationship, we define *two* links: one in each
   direction.

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

   Our constants are primitive queries.

   A *constant* maps any input to a fixed value.

   * Query output: the type of the constant value.

   * Query input?  Could be anything; constants are *polymorphic* in their input.

   .. math::

      &\operatorname{true} & : A&\to\operatorname{Bool} \\
      &1024 & : A&\to\operatorname{Int} \\
      &\texttt{"Rabbit"} & : A&\to\operatorname{Text}


.. slide:: Primitives: :math:`\operatorname{null}` and :math:`\operatorname{here}`
   :level: 3

   There is a special constant that indicates lack of any value:

   .. math::

      \operatorname{null} : A \to \operatorname{Opt}\{\operatorname{Union}\{\}\}

   Its output type allows :math:`\operatorname{null}` satisfy any type
   constraints.

   Our last primitive: the *identity* function.

   Identity primitive maps any value to itself.

   .. math::

      \operatorname{here} : A \to A


