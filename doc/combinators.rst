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

   *What is a database query?*

   Examples of queries:

   :math:`Q_1`. *Show the total number of departments.*

   :math:`Q_2`. *For every department, show its name and the number of
   employees.*

   Formally, we need to define a (possibly parametric) type

   .. math:: \operatorname{Query}

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


