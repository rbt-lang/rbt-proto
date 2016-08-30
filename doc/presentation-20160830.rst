Rabbit as Query Arithmetics
===========================

.. slide:: Rabbit as Query Arithmetics
   :level: 2

   Remember elementary arithmetics:

   .. math:: (3 + 4) * 6

   * Highly regular.
   * Easy to learn.
   * Easy to use.

   Can we present *database querying* in the form of an arithmetic?

   First, we need to understand how regular arithmetics is organized.


.. slide:: Structure of Elementary Arithmetics
   :level: 3

   How is elementary arithmetics structured?

   We have:

   1. *domain objects:* numbers.

   2. *primitives:* number literals :math:`(0, 1, -1, 2, \ldots)`.

   3. *combinators:* arithmetic operations :math:`(+, -, \sqrt{\cdot}, \ldots)`.

   Primitives are elementary domain objects.

   Each combinator takes one or more domain objects and produces a new object.

   It is easier to identify primitives and combinators if we write arithmetic
   expressions in functional form:

   .. math:: \operatorname{mul}(\operatorname{add}(3,4),6)


.. slide:: Structure of Query Arithmetics
   :level: 3

   Can we structure database querying in form of an arithmetic?

   We need to define domain objects, primitives and combinators.

   1. What is a database query?

   2. Where to get atomic queries?

   3. What are query operations?

   Where do we start with answering these questions?


.. slide:: Schema Diagram
   :level: 2

   For inspiration, let us take a look at a schema diagram.

   For example, take a textbook "department & employees" database:

   .. graphviz:: citydb-unfolding-step-1.dot

   What does this diagram represent?


.. slide:: Meaning of a Schema Diagram
   :level: 3

   .. graphviz:: citydb-unfolding-step-1.dot

   On this diagram, we see:

   * Entity classes and attribute types:
     :math:`\operatorname{Dept},\; \operatorname{Empl},\; \operatorname{Text},\; \operatorname{Int}`

   * Attributes and relationships:

     .. math::

        &\operatorname{name} & : \operatorname{Dept}&\to\operatorname{Text} \\
        &\operatorname{department} & : \operatorname{Empl}&\to\operatorname{Dept}



.. slide:: The Idea: Primitives
   :level: 3

   Here is the idea:

   2. Let attributes and relationships be primitive queries:

      *For the given department entity, produce the department name.*

      .. math::

         \operatorname{name} : \operatorname{Dept} \to \operatorname{Text}

      *For the given employee entity, produce the respective department entity.*

      .. math::

         \operatorname{department} : \operatorname{Empl} \to \operatorname{Dept}


.. slide:: The Idea: Combinators
   :level: 3

   Here is the idea:

   3. Then composition becomes a binary query combinator:

      *For the given employee entity, produce the name of their department.*

      Composing two primitive queries:

      .. math::

         &\operatorname{department} & : \operatorname{Empl}&\to\operatorname{Dept} \\
         &\operatorname{name} & : \operatorname{Dept}&\to\operatorname{Text}

      we get:

      .. math::

         \operatorname{department}{.}\operatorname{name}
         : \operatorname{Empl} \to \operatorname{Text}


.. slide:: The Idea: Query Interface
   :level: 3

   1. What is a query, in general?

      *For the given input of type* :math:`A`, *produce output of type* :math:`B`.

      .. math:: Q : A \to B

      Note: query arithmetics is multi-sorted, therefore each query combinator
      requires specific *signatures* of input queries.

      Example: *composition combinator*.  Given two queries with signatures:

      .. math:: Q_1 : A \to B, \qquad Q_2 : B \to C

      their composition is a query with signature:

      .. math:: Q_1{.}Q_2 : A \to C

   Are we done yet?  Not quite.


.. slide:: The Idea: Limitations
   :level: 3

   Do we have enough tools to construct queries of arbitrary complexity?

   Not really.  In fact, there is only one query we could possibly construct:

   .. math:: \operatorname{department}{.}\operatorname{name}

   The problem: query interface is not flexible enough.  Consider:

   * Relationship that associates every department to the set of the respective
     employees.

   * Relationship that associates every employee to their manager.

   * Collection of all departments/all employees.


.. slide:: Plural Relationships
   :level: 2

   Consider a relationship: *Every employee is associated with their
   department.*

   We represent it by a primitive query:

   .. math::

      \operatorname{department} : \operatorname{Empl}\to\operatorname{Dept}

   But we could also *invert* this relationship:

   *A department is associated with the respective employees.*

   Is there a query representing it?  Perhaps we can introduce a new primitive?

   .. math::

      \operatorname{employee} : \operatorname{Dept}\to\operatorname{Empl}\;?

   But it doesn't work because for a given department, there are multiple
   employees.

   This is called *a plural relationship*.


.. slide:: Partial Relationships
   :level: 3

   Suppose we want to introduce a new relationship:

   *An employee is associated with their manager.*

   Can we add a primitive representing this relationship?  If so, what is its
   signature?

   .. math::

      \operatorname{managed\_by} : \operatorname{Empl}\to\operatorname{Empl}\;?

   But not every employee has a manager! (The CEO doesn't).

   This is called *a partial relationship*.

   Note: there is also an inverse relationship :math:`\operatorname{manages}`,
   which maps employees to their direct subordinates.  It is plural.


.. slide:: Expressing Plural and Partial Relationships
   :level: 3

   To express plural and partial relationships, we need to adjust query interface.

   We introduce *cardinality modifiers*:

   * :math:`\operatorname{Seq}\{T\}` is a finite sequence of values of type
     :math:`T`.

   * :math:`\operatorname{Opt}\{T\}` is zero or one value of type :math:`T`.

   This lets us define new primitives:

   .. math::

      &\operatorname{employee} & : \operatorname{Dept}&\to\operatorname{Seq}\{\operatorname{Empl}\} \\
      &\operatorname{managed\_by} & : \operatorname{Empl}&\to\operatorname{Opt}\{\operatorname{Empl}\}

   Are we good now?


.. slide:: Expressing Plural and Partial Relationships: Composition
   :level: 3

   We also need to update rules for query composition.  Consider:

   .. math::

      &\operatorname{employee} & : \operatorname{Dept}&\to\operatorname{Seq}\{\operatorname{Empl}\} \\
      &\operatorname{position} & : \operatorname{Empl}&\to\operatorname{Text}

   Or:

   .. math::

      &\operatorname{managed\_by} & : \operatorname{Empl}&\to\operatorname{Opt}\{\operatorname{Empl}\} \\
      &\operatorname{salary} & : \operatorname{Empl}&\to\operatorname{Int}

   Can we form compositions of these queries?

   .. math::

      \operatorname{employee}{.}\operatorname{position}, \quad
      \operatorname{managed\_by}{.}\operatorname{salary}

   If so, what are their signatures?


.. slide:: Composition with Cardinality Modifiers
   :level: 3

   We need to update composition rules to work in the presence of cardinality
   modifiers.  Consider:

   .. math::

      Q_1: A \to M_1\{B\}, \qquad Q_2 : B \to M_2\{C\}

   Composition of :math:`Q_1` and :math:`Q_2` must have the form:

   .. math:: Q_1{.}Q_2 : A \to M\{C\}

   Here, cardinality modifier :math:`M` is defined as the *join* (or *least
   upper bound*) of :math:`M_1` and :math:`M_2`:

   .. math:: M = M_1 \vee M_2


.. slide:: Composition with Cardinality Modifiers: Example
   :level: 3

   How does it work in practice?  Consider our previous examples:

   .. math::

      &\operatorname{employee} & : \operatorname{Dept}&\to\operatorname{Seq}\{\operatorname{Empl}\} \\
      &\operatorname{position} & : \operatorname{Empl}&\to\operatorname{Text}

   Or:

   .. math::

      &\operatorname{managed\_by} & : \operatorname{Empl}&\to\operatorname{Opt}\{\operatorname{Empl}\} \\
      &\operatorname{salary} & : \operatorname{Empl}&\to\operatorname{Int}

   We can now compose them:

   .. math::

      &\operatorname{employee}{.}\operatorname{position} &: \operatorname{Dept} &\to \operatorname{Seq}\{\operatorname{Text}\} \\
      &\operatorname{managed\_by}{.}\operatorname{salary} &: \operatorname{Empl} &\to \operatorname{Opt}\{\operatorname{Int}\}


.. slide:: Class Relationships
   :level: 2

   We need a way to express the set of all entities of a particular class.

   *Show a list of all departments.*

   We have notation for the set of all departments:
   :math:`\operatorname{Dept}`.

   But this is not a query!  A query must have the form :math:`A \to M\{B\}`.

   What is the signature of a query that produces a list of all departments?

   .. math:: (?) \to \operatorname{Seq}\{\operatorname{Dept}\}

   Its output is a sequence of department entities.

   But what is its input?


.. slide:: Singleton Type
   :level: 3

   Let us introduce *a singleton type* (that is, a type with a single value):

   .. math::

      \operatorname{Void} \quad (\operatorname{nothing}:\operatorname{Void})

   We use singleton type as input for class queries:

   .. math::

      &\operatorname{department} & : \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Dept}\} \\
      &\operatorname{employee} & : \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Empl}\}

   A class query maps value :math:`\operatorname{nothing}` to a sequence of all
   entities of a particular class.


.. slide:: Summary
   :level: 2

   Recall how we started.  To define query arithmetics, we need to define:

   1. What is a query?

   2. A collection of primitive queries.

   3. Query combinators.

   We are now ready to present them.


.. slide:: Summary: Query Interface
   :level: 3

   A query is a mapping with generic signature:

   .. math:: Q : A \to M\{B\}

   It represents a query :math:`Q` which takes input of type :math:`A` and
   produces output of type :math:`B` and cardinality :math:`M`.

   When the query does not take any input, we substitute :math:`A` by singleton
   type :math:`\operatorname{Void}`.


.. slide:: Summary: Class Primitives
   :level: 3

   Primitive queries come from the schema.

   A class primitive produces all entities of a specific class:

   .. math::

      &\operatorname{department} & : \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Dept}\} \\
      &\operatorname{employee} & : \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Empl}\}


.. slide:: Summary: Attribute Primitives
   :level: 3

   Primitive queries come from the schema.

   An attribute primitive maps an entity to the value of its attribute:

   .. math::

      &\operatorname{name} & : \operatorname{Dept}&\to\operatorname{Text} \\
      &\operatorname{name} & : \operatorname{Empl}&\to\operatorname{Text} \\
      &\operatorname{position} & : \operatorname{Empl}&\to\operatorname{Text} \\
      &\operatorname{salary} & : \operatorname{Empl}&\to\operatorname{Int}


.. slide:: Summary: Link Primitives
   :level: 3

   A link primitive maps an entity to a related entity or entities.

   .. math::

      &\operatorname{employee} & : \operatorname{Dept}&\to\operatorname{Seq}\{\operatorname{Empl}\} \\
      &\operatorname{department} & : \operatorname{Empl}&\to\operatorname{Dept} \\
      &\operatorname{manages} & : \operatorname{Empl}&\to\operatorname{Seq}\{\operatorname{Empl}\} \\
      &\operatorname{managed\_by} & : \operatorname{Empl}&\to\operatorname{Opt}\{\operatorname{Empl}\}


.. slide:: Summary: Composition Combinator
   :level: 3

   We introduced just one query combinator: binary composition operator.

   Given two queries with shared intermediate type:

   .. math::

      Q_1: A \to M_1\{B\}, \qquad Q_2 : B \to M_2\{C\}

   Composition of :math:`Q_1` and :math:`Q_2` has the form:

   .. math:: Q_1{.}Q_2 : A \to M\{C\}

   Here, cardinality modifier :math:`M` is defined by:

   .. math:: M = M_1 \vee M_2

   Many other query combinators could be defined!


.. slide:: Summary: Benefits
   :level: 3

   What can we do with this model?  Amazingly, it has everything we need to
   construct highly sophisticated queries.  We just need more specialized query
   combinators.

   In particular, we can:

   * Traverse, aggregate, filter, sort, paginate and select output data.
   * Construct grouping and cube queries.
   * Query hierarchical data.
   * Support query parameters.
   * Use running aggregates.


.. slide:: Traversing Data 1
   :level: 2

   *Show the name of each department.*

   We construct this query by composing two primitives:

   .. math::

      &\operatorname{department} & : \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Dept}\} \\
      &\operatorname{name} & : \operatorname{Dept}&\to\operatorname{Text}

   Their composition is a query with signature:

   .. math::

      \operatorname{department}{.}\operatorname{name} :
      \operatorname{Void}\to\operatorname{Seq}\{\operatorname{Text}\}


.. slide:: Traversing Data 2
   :level: 3

   *Show the name of each department.*

   Let us run it:

   .. code-block:: julia

      department.name

   Output is a sequence of text values:

   .. code-block:: julia

      "WATER MGMNT"
      "POLICE"
      ⋮
      "LICENSE APPL COMM"


.. slide:: Traversing Data 3
   :level: 3

   *For each department, show the name of each employee.*

   This query is composed out of three primitives:

   .. math::

      &\operatorname{department} & : \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Dept}\} \\
      &\operatorname{employee} & : \operatorname{Dept}&\to\operatorname{Seq}\{\operatorname{Empl}\} \\
      &\operatorname{name} & : \operatorname{Empl}&\to\operatorname{Text}

   The signature of this query is:

   .. math::

      \operatorname{department}{.}\operatorname{employee}{.}\operatorname{name} :
      \operatorname{Void}\to\operatorname{Seq}\{\operatorname{Text}\}


.. slide:: Traversing Data 4
   :level: 3

   *For each department, show the name of each employee.*

   .. code-block:: julia

      department.employee.name

   .. code-block:: julia

      "ELVIA A"
      "VICENTE A"
      "MUHAMMAD A"
      "GIRLEY A"
      ⋮
      "MICHELLE G"

   We got a list where each employee appears once.  Why?

   Because each employee belongs to one and only one department.

   Can we get the same data without going through
   :math:`\operatorname{department}`?


.. slide:: Traversing Data 5
   :level: 3

   We can get a list of employee names directly.

   *Show the name of each employee.*

   The respective query is:

   .. math::

      \operatorname{employee}{.}\operatorname{name} :
      \operatorname{Void}\to\operatorname{Seq}\{\operatorname{Text}\}

   It is composed out of two primitives:

   .. math::

      &\operatorname{employee} & : \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Empl}\} \\
      &\operatorname{name} & : \operatorname{Empl}&\to\operatorname{Text}


.. slide:: Traversing Data 6
   :level: 3

   *Show the name of each employee.*

   .. code-block:: julia

      employee.name

   .. code-block:: julia

      "ELVIA A"
      "JEFFERY A"
      "KARINA A"
      "KIMBERLEI A"
      ⋮
      "DARIUSZ Z"

   Compare this with the output of:

   .. code-block:: julia

      department.employee.name

   We got a list of the same items, but not necessarily in the same order.


.. slide:: Traversing Data 7
   :level: 3

   What if we traverse :math:`\operatorname{department}` through
   :math:`\operatorname{employee}`?

   *For each employee, show the name of their department.*

   This is the query:

   .. math::

      \operatorname{employee}{.}\operatorname{department}{.}\operatorname{name} :
      \operatorname{Void}\to\operatorname{Seq}\{\operatorname{Text}\}

   It is composed out of three primitives:

   .. math::

      &\operatorname{employee} & : \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Empl}\} \\
      &\operatorname{department} & : \operatorname{Empl}&\to\operatorname{Dept} \\
      &\operatorname{name} & : \operatorname{Dept}&\to\operatorname{Text}


.. slide:: Traversing Data 8
   :level: 3

   *For each employee, show the name of their department.*

   .. code-block:: julia

      employee.department.name

   .. code-block:: julia

      "WATER MGMNT"
      "POLICE"
      "POLICE"
      "GENERAL SERVICES"
      ⋮
      "DoIT"

   This is *not* the same as the query ``department.name``.

   * One line for each *employee* entity.
   * Most department names appear more than once.
   * It may happen that some departments do not appear at all.


.. slide:: Traversing Data 9
   :level: 3

   Can we get a list of employee positions?

   *Show the position of each employee.*

   Let us try:

   .. math::

      \operatorname{employee}{.}\operatorname{position} :
      \operatorname{Void}\to\operatorname{Seq}\{\operatorname{Text}\}

   It is composed out of two primitives:

   .. math::

      &\operatorname{employee} & : \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Empl}\} \\
      &\operatorname{position} & : \operatorname{Empl}&\to\operatorname{Text}


.. slide:: Traversing Data 10
   :level: 3

   *Show the position of each employee.*

   .. code-block:: julia

      employee.position

   .. code-block:: julia

      "WATER RATE TAKER"
      "POLICE OFFICER"
      "POLICE OFFICER"
      "CHIEF CONTRACT EXPEDITER"
      ⋮
      "CHIEF DATA BASE ANALYST"

   You can spot duplicates in the output.

   Again, this is because we asked for one value for each *employee* entity.

   Is it possible to get a list of *unique* positions?  We can, using the
   :math:`\operatorname{group}` combinator.


.. slide:: Traversing Data 11
   :level: 3

   What happens if we ask for a list of entities?

   *Show all employees.*

   For convenience, an entity value is substituted with a tuple of its
   attributes.

   The query signature is:

   .. math::

      \operatorname{employee} : \operatorname{Void}\to\operatorname{Seq}\{\operatorname{Empl}\}

   The *formatter* converts this query to the form:

   .. math::

      &\operatorname{employee}{.}(
      \operatorname{name},\;
      \operatorname{department}{.}\operatorname{name},\;
      \operatorname{position},\;
      \operatorname{salary}): \\
      &\qquad\qquad \operatorname{Void} \to
      \operatorname{Seq}\{\operatorname{Tuple}\{\operatorname{Text},\operatorname{Text},\operatorname{Text},\operatorname{Int}\}\}


.. slide:: Traversing Data 12
   :level: 3

   *Show all employees.*

   .. code-block:: julia

      employee

   .. code-block:: julia

      ("ELVIA A","WATER MGMNT","WATER RATE TAKER",88968)
      ("JEFFERY A","POLICE","POLICE OFFICER",80778)
      ("KARINA A","POLICE","POLICE OFFICER",80778)
      ("KIMBERLEI A","GENERAL SERVICES","CHIEF CONTRACT EXPEDITER",84780)
      ⋮
      ("DARIUSZ Z","DoIT","CHIEF DATA BASE ANALYST",110352)


.. slide:: Summarizing Data 1
   :level: 2

   We learned to use composition to traverse the data.

   How can we *summarize* data?

   Consider a query:

   *Show the number of all departments.*

   * We know how to get a sequence of all departments:

     .. math::

        \operatorname{department} : \operatorname{Void} \to \operatorname{Seq}\{\operatorname{Dept}\}

   * How to get *the number* of all departments?


.. slide:: Summarizing Data 2
   :level: 3

   *Show the number of all departments.*

   What is the signature of this query?  It produces a single number, so:

   .. math::

      \operatorname{Void} \to \operatorname{Int}

   We start with a sequence of all departments:

   .. math::

      \operatorname{department} : \operatorname{Void} \to \operatorname{Seq}\{\operatorname{Dept}\}

   We need to transform it to *the number* of departments.

   That is, we need an operation with a signature:

   .. math::

      (\operatorname{Void} \to \operatorname{Seq}\{\operatorname{Dept}\})
      \to (\operatorname{Void} \to \operatorname{Int})

   We call this operation: the :math:`\operatorname{count}` combinator.


.. slide:: Summarizing Data 3
   :level: 3

   Unary combinator :math:`\operatorname{count}` has signature:

   .. math::

      \operatorname{count} : (A \to \operatorname{Seq}\{B\})
      \to (A \to \operatorname{Int})

   Here, :math:`A`, :math:`B` stand for arbitrary types.

   This signature means that, given any query :math:`Q` with signature:

   .. math:: Q: A \to \operatorname{Seq}\{B\}

   Query :math:`\operatorname{count}(Q)` has signature:

   .. math:: \operatorname{count}(Q) : A \to \operatorname{Int}


.. slide:: Summarizing Data 4
   :level: 3

   *Show the number of all departments.*

   Use the combinator:

   .. math::

      \operatorname{count}(Q:A\to\operatorname{Seq}\{B\}) : A\to\operatorname{Int}

   Substitute: :math:`Q` with :math:`\operatorname{department}`, :math:`A` with
   :math:`\operatorname{Void}`, :math:`B` with :math:`\operatorname{Dept}`.

   We obtain query:

   .. math::

      \operatorname{count}(\operatorname{department}) : \operatorname{Void} \to \operatorname{Int}

   .. code-block:: julia

      count(department)

   .. code-block:: julia

      35


.. slide:: Summarizing Data 5
   :level: 3

    A combinator that maps a plural query to a singular query is called an
    *aggregate*.

    Examples:

   .. math::

      &\operatorname{count} & : (A\to\operatorname{Seq}\{B\})&\to(A\to\operatorname{Int}) \\
      &\operatorname{exists} & : (A\to\operatorname{Seq}\{B\})&\to(A\to\operatorname{Bool}) \\
      &\operatorname{any},\operatorname{all} & :
      (A\to\operatorname{Seq}\{\operatorname{Bool}\})&\to(A\to\operatorname{Bool}) \\
      &\operatorname{sum} & :
      (A\to\operatorname{Seq}\{\operatorname{Int}\})&\to(A\to\operatorname{Int}) \\
      &\operatorname{max},\operatorname{min} & :
      (A\to\operatorname{Seq}\{B\})&\to(A\to\operatorname{Opt}\{B\})

   Why :math:`\operatorname{Opt}` on the output of :math:`\operatorname{max}`
   and :math:`\operatorname{min}`?  What if the input is empty?


.. slide:: Summarizing Data 6
   :level: 3

   Just with aggregates and composition, we can construct complex queries.

   Example (an aggregate over composition):

   *Show the highest salary among all employees.*

   1. All salaries:

      .. math::

         \operatorname{employee}{.}\operatorname{salary} : \operatorname{Void}\to\operatorname{Seq}\{\operatorname{Int}\}

   2. The maximum of all salaries:

      .. math::

         \operatorname{max}(\operatorname{employee}{.}\operatorname{salary}) : \operatorname{Void}\to\operatorname{Opt}\{\operatorname{Int}\}

   .. code-block:: julia

      max(employee.salary)

   .. code-block:: julia

      260004


.. slide:: Summarizing Data 7
   :level: 3

   Example (composition with an aggregate):

   *Show the number of employees in each department.*

   1. Number of employees for the given department:

      .. math::

         \operatorname{count}(\operatorname{employee}) : \operatorname{Dept}\to\operatorname{Int}

   2. Number of employees for each department:

      .. math::

         \operatorname{department}{.}\operatorname{count}(\operatorname{employee}) :
         \operatorname{Void}\to\operatorname{Seq}\{\operatorname{Int}\}

   .. code-block:: julia

      department.count(employee)

   .. code-block:: julia

      1848
      13570
      ⋮
      1


.. slide:: Summarizing Data 8
   :level: 3

   We conclude with an example of an aggregate over another aggregate.

   *Show the highest number of employees per department.*

   1. Number of employees for each department:

      .. math::

         \operatorname{department}{.}\operatorname{count}(\operatorname{employee}) :
         \operatorname{Void}\to\operatorname{Seq}\{\operatorname{Int}\}

   2. The highest number of employees for each department:

      .. math::

         \operatorname{max}(\operatorname{department}{.}\operatorname{count}(\operatorname{employee})) :
         \operatorname{Void}\to\operatorname{Opt}\{\operatorname{Int}\}

   .. code-block:: julia

      max(department.count(employee))

   .. code-block:: julia

      32181


.. slide:: Pipeline Notation
   :level: 2

   What we covered so far: *traversal*, *aggregates*.

   What is left: *selection*, *filtering*.

   Before we proceed, let us introduce a new syntax construction.

   *Pipeline notation* lets you chain combinators to form a data processing
   pipeline.

   Analogy: shell pipeline.


.. slide:: Pipeline Notation: Syntax
   :level: 3

   The idea: place the argument in front of the combinator.

   .. math::

      &Q{:}F \quad &\text{is desugared to} \quad &F(Q) \\
      &Q_1{:}F(Q_2,\ldots) \quad &\text{is desugared to} \quad &F(Q_1,Q_2,\ldots)

   A simple example (before and after desugaring):

   .. code-block:: julia

      department:count

   .. code-block:: julia

      count(department)

   Both examples are equivalent.

   How to use this notation to build a data pipeline?


.. slide:: Pipeline Notation: Example
   :level: 3

   We use pipeline notation to chain combinators into a data processing
   pipeline.

   Typical usage:

   .. code-block:: julia

      employee
      :filter(department.name == "POLICE")
      :group(position)
      :select(position, count(employee), mean(employee.salary))

   This data pipeline contains four steps:

   1. Start with a list of all employees.
   2. Filter the list by a predicate condition.
   3. Group it by an attribute.
   4. Select fields for output.


.. slide:: Pipeline Notation: Desugaring Example
   :level: 3

   Example (before and after desugaring):

   .. code-block:: julia

      employee
      :filter(department.name == "POLICE")
      :group(position)
      :select(position, count(employee), mean(employee.salary))

   .. code-block:: julia

      select(
          group(
              filter(
                  employee,
                  department.name == "POLICE"),
              position),
          position,
          count(employee),
          mean(employee.salary))

   Next, we will describe :math:`\operatorname{select}` and
   :math:`\operatorname{filter}` combinators.


.. slide:: Selecting Output 1
   :level: 2

   The :math:`\operatorname{select}` combinator is one of the most complex
   query combinators.  Here, we present a simplified account.

   The :math:`\operatorname{select}` combinator has the form:

   .. math::

      \operatorname{select}(Q, F_1, F_2, \ldots, F_n)

   Typically, written in pipeline notation as:

   .. math::

      Q{:}\operatorname{select}(F_1, F_2, \ldots, F_n)

   * :math:`Q` is the base of the selection.
   * :math:`F_1,F_2,\ldots,F_n` are selected fields.


.. slide:: Selecting Output 2
   :level: 3

   Let us describe the signature of the :math:`\operatorname{select}`
   combinator:

   .. math::

      \operatorname{select}(Q, F_1, F_2, \ldots, F_n)

   * The base of selection could be any plural query:

     .. math::

        Q : A \to \operatorname{Seq}\{B\}

   * Selected fields operate on the output of :math:`Q`:

     .. math::

        F_k : B \to C_k \quad (k=1,2,\ldots,n)

   * :math:`\operatorname{select}` accepts the input of :math:`Q` and emits the
     combined output of all fields:

     .. math::

        \operatorname{select}(Q,F_1,F_2,\ldots,F_n) :
        A \to \operatorname{Seq}\{\operatorname{Tuple}\{C_1,C_2,\ldots,C_n\}\}


.. slide:: Selecting Output 3
   :level: 3

   *For every department, show its name and the number of employees:*

   .. math::
      :nowrap:

      \begin{multline}
      \operatorname{department}{:}
      \operatorname{select}(
      \operatorname{name},
      \operatorname{count}(\operatorname{employee})) : \\
      \operatorname{Void}\to\operatorname{Seq}\{\operatorname{Tuple}\{\operatorname{Text},\operatorname{Int}\}\}
      \end{multline}

   * Base: *Show each department:*

     .. math::

        \operatorname{department}:\operatorname{Void}\to\operatorname{Seq}\{\operatorname{Dept}\}

   * Field 1: *For the given department, show its name:*

   .. math::

      \operatorname{name}:\operatorname{Dept}\to\operatorname{Text}

   * Field 2: *For the given department, show the number of employees:*

     .. math::

        \operatorname{count}(\operatorname{employee}):\operatorname{Dept}\to\operatorname{Int}


.. slide:: Selecting Output 4
   :level: 3

   *For every employee, show their name, department, position and salary.*

   .. code-block:: julia

      employee
      :select(
          name,
          department.name,
          position,
          salary)

   .. code-block:: julia

      ("ELVIA A","WATER MGMNT","WATER RATE TAKER",88968)
      ("JEFFERY A","POLICE","POLICE OFFICER",80778)
      ("KARINA A","POLICE","POLICE OFFICER",80778)
      ("KIMBERLEI A","GENERAL SERVICES","CHIEF CONTRACT EXPEDITER",84780)
      ⋮
      ("DARIUSZ Z","DoIT","CHIEF DATA BASE ANALYST",110352)


.. slide:: Selecting Output 5
   :level: 3

   *For every department, show its name and the name and the position of its
   employees.*

   .. code-block:: julia

      department
      :select(
          name,
          employee:select(name,position))

   .. code-block:: julia

      ("WATER MGMNT",[("ELVIA A","WATER RATE TAKER"),("VICENTE A","CIVIL ENGINEER IV"),…])
      ("POLICE",[("JEFFERY A","POLICE OFFICER"),("KARINA A","POLICE OFFICER"),…])
      ⋮
      ("LICENSE APPL COMM",[("MICHELLE G","STAFF ASST")])


.. slide:: Filtering Data 1
   :level: 2

   We learned how to produce all entities of a particular class.

   Example: *Show all employees.*

   .. math::

      \operatorname{employee}

   How can we produce entities that satisfy a particular condition?

   Example: *Show all employees with salary higher than $200k.*

   We use the :math:`\operatorname{filter}` combinator:

   .. math::

      \operatorname{employee}{:}\operatorname{filter}(\operatorname{salary}>200000)


.. slide:: Filtering Data 2
   :level: 3

   *Show all employees with salary higher than $200k.*

   .. math::

      \operatorname{employee}{:}\operatorname{filter}(\operatorname{salary}>200000)

   After desugaring, this query transforms to:

   .. math::

      \operatorname{filter}(\operatorname{employee},{>}(\operatorname{salary},200000))

   New concepts:

   * Constant primitive: :math:`200000`.
   * Predicate combinator: :math:`>`.
   * Filtering combinator: :math:`\operatorname{filter}`.


.. slide:: Constants
   :level: 3

   Any constant is a primitive query.

   A constant query maps any input to the same output.

   Signature:

   * Input could be of any type.
   * Output has the type of the constant value.

   Examples:

   .. math::

      &200000 &: A &\to \operatorname{Int} \\
      &\texttt{"POLICE"} &: A &\to \operatorname{Text} \\
      &\operatorname{true} &: A &\to \operatorname{Bool}



.. slide:: Scalar Combinators
   :level: 3

   This query fragment is an application of the :math:`>` combinator:

   .. math::

      \operatorname{salary}>200000

   We know a predicate function:

   .. math::

      {>} : \operatorname{Int}\times\operatorname{Int}\to\operatorname{Bool}

   How is it transformed into a query combinator?

   .. math::

      {>}(Q_1, Q_2)

   The idea: apply the predicate to the output of :math:`Q_1` and :math:`Q_2`.


.. slide:: Scalar Combinators: Signature
   :level: 3

   What is the signature of this predicate combinator?

   .. math::

      {>}(Q_1, Q_2)

   * :math:`Q_1` and :math:`Q_2` have input of any type and integer output:

     .. math::

        Q_1, Q_2 : A \to \operatorname{Int}

   * The :math:`>` combinator has the same input as :math:`Q_1` and :math:`Q_2`
     and Boolean output:

     .. math::

        {>}(Q_1, Q_2) : A \to \operatorname{Bool}

   We write the signature of the :math:`>` combinator as follows:

   .. math::

      {>} : (A\to\operatorname{Int}) \times (A\to\operatorname{Int}) \to (A\to\operatorname{Bool})


.. slide:: Scalar Combinators: Examples
   :level: 3

   Any scalar function could be converted to a combinator.

   Examples:

   .. math::

      &{=},{\ne} &: (A \to B) \times (A \to B) &\to (A \to \operatorname{Bool}) \\
      &{\&},{|} &: (A \to \operatorname{Bool}) \times (A \to \operatorname{Bool}) &\to (A \to \operatorname{Bool}) \\
      &\operatorname{contains} &: (A \to \operatorname{Text}) \times (A \to \operatorname{Text}) &\to (A \to \operatorname{Bool}) \\
      &{+},{-} &: (A \to \operatorname{Int}) \times (A \to \operatorname{Int}) &\to (A \to \operatorname{Int}) \\
      &\operatorname{round} &: (A \to \operatorname{Float}) &\to (A \to \operatorname{Int})


.. slide:: Filtering Data 3
   :level: 3

   The :math:`\operatorname{filter}` combinator has the form:

   .. math::

      \operatorname{filter}(Q, P)

   Typically written in pipeline notation:

   .. math::

      Q{:}\operatorname{filter}(P)


.. slide:: Filtering Data 4
   :level: 3

   What is the signature of the combinator :math:`\operatorname{filter}(Q, P)`?

   * The base :math:`Q` is any plural query:

     .. math::

        Q : A \to \operatorname{Seq}\{B\}

   * The predicate :math:`P` is a Boolean query operating on values of
     :math:`Q`:

     .. math::

        P : B \to \operatorname{Bool}

   The :math:`\operatorname{filter}` combinator has the same signature as its
   base:

   .. math::

      \operatorname{filter}(Q, P) : A \to \operatorname{Seq}\{B\}


.. slide:: Filtering Data 5
   :level: 3

   Often, filtering is one of the steps in a data pipeline.

   *For each employee with salary higher than $200K, show their name, position
   and salary.*

   .. code-block:: julia

      employee
      :filter(salary > 200000)
      :select(name, position, salary)

   .. code-block:: julia

      ("RAHM E","MAYOR",216210)
      ("GARRY M","SUPERINTENDENT OF POLICE",260004)
      ("JOSE S","FIRE COMMISSIONER",202728)


.. slide:: Filtering Data 6
   :level: 3

   The filter condition may contain complex expressions including aggregates.

   *Show the names of departments with more than 1000 employees.*

   .. code-block:: julia

      department
      :filter(count(employee)>1000)
      .name

   .. code-block:: julia

      "WATER MGMNT"
      "POLICE"
      ⋮
      "TRANSPORTN"


.. slide:: Filtering Data 7
   :level: 3

   A filtered expression can be used as a component of an aggregate.

   *Find the number of departments with more than 1000 employees.*

   .. code-block:: julia

      count(
          department
          :filter(count(employee) > 1000))

   .. code-block:: julia

      7


.. slide:: Conclusion
   :level: 2

   Consider this final example:

   *For each department, show the number of employees with salary higher than
   100k.*

   We can now write this query:

   .. code-block:: julia

      department
      :select(
          name,
          count(
              employee
              :filter(salary > 100000)))

   .. code-block:: julia

      ("WATER MGMNT",179)
      ("POLICE",1493)
      ⋮
      ("LICENSE APPL COMM",0)


