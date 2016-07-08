Quotients
=========


.. slide:: Mapping a Query onto the Schema
   :level: 2

   So far, we only considered queries that can be mapped to the schema
   structure.

   .. graphviz:: citydb-unfolded-data-model.dot

   Example: *For each department, show its name and a list of employees.*

   How does it map to the schema?


.. slide:: Mapping a Query onto the Schema: Example
   :level: 3

   *For each department, show its name and a list of employees.*

   .. graphviz:: citydb-unfolded-department-name-employee-name.dot

   We can easily write this query by enumerating nodes in the selected subtree:

   .. math::

      \operatorname{department}
      {:}\operatorname{select}(\operatorname{name},\operatorname{employee}{.}\operatorname{name})


.. slide:: Mapping a Query onto the Schema: Two Queries
   :level: 3

   *For each department, show its name and a list of employees.*

   .. code-block:: julia

      department
      :select(
          name,
          employee.name)


   .. code-block:: julia

      ("WATER MGMNT",["ELVIA A","VICENTE A",…])
      ("POLICE",["JEFFERY A","KARINA A",…])
      ⋮
      ("LICENSE APPL COMM",["MICHELLE G"])

   Is it always that easy?  Consider a different query:

   *For each position, show a list of respective employees.*


.. slide:: Mapping a Query onto the Schema: a Problem
   :level: 3

   *For each position, show a list of respective employees.*

   We will have a hard time trying to map this query to a subtree of the
   schema.

   .. graphviz:: citydb-unfolded-position-employee-name.dot


.. slide:: Mapping a Query onto the Schema: Solution?
   :level: 3

   *For each position, show a list of respective employees.*

   If only we could transform the schema to place
   :math:`\operatorname{position}` on top?

   .. graphviz:: citydb-unfolded-employee-group-position.dot

   In this section, we learn how to adapt the database structure for a given
   query.


.. slide:: Unique Values
   :level: 2

   We start with a simple query:

   *Show a list of all positions.*

   We can get a list of positions of all employees:

   .. code-block:: julia

      employee.position

   .. code-block:: julia

      "WATER RATE TAKER"
      "POLICE OFFICER"
      "POLICE OFFICER"
      "CHIEF CONTRACT EXPEDITER"
      ⋮
      "CHIEF DATA BASE ANALYST"

   The problem is: this list contains duplicate values.

   Can we make a list of all *distinct* employee positions?


.. slide:: The :math:`\operatorname{unique}` Combinator
   :level: 3

   *Show a list of all positions.*

   We start with a list of positions for all employees:

   .. math::

      \operatorname{employee}{.}\operatorname{position}

   To filter out duplicates, we use the :math:`\operatorname{unique}`
   combinator:

   .. math::

      \operatorname{unique}(\operatorname{employee}{.}\operatorname{position})

   This gives us a list of all distinct positions.


.. slide:: The :math:`\operatorname{unique}` Combinator: Output
   :level: 3

   *Show a list of all positions.*

   .. code-block:: julia

      unique(employee.position)

   .. code-block:: julia

      "1ST DEPUTY INSPECTOR GENERAL"
      "A/MGR COM SVC-ELECTIONS"
      "A/MGR OF MIS-ELECTIONS"
      "A/MGR WAREHOUSE-ELECTIONS"
      ⋮
      "ZONING PLAN EXAMINER"


.. slide:: The :math:`\operatorname{unique}` Combinator: Signature
   :level: 3

   *Show a list of all positions.*

   The :math:`\operatorname{unique}` combinator preserves the shape of the
   query:

   .. math::

      & \operatorname{employee}{.}\operatorname{position} &:
      \operatorname{Void} &\to \operatorname{Seq}\{\operatorname{Text}\} \\
      & \operatorname{unique}(\operatorname{employee}{.}\operatorname{position}) &:
      \operatorname{Void} &\to \operatorname{Seq}\{\operatorname{Text}\} \\

   Hence, in general, its signature is:

   .. math::

      \operatorname{unique} : (A\to\operatorname{Seq}\{B\})\to(A\to\operatorname{Seq}\{B\})


.. slide:: The :math:`\operatorname{unique}` Combinator: Example
   :level: 3

   The :math:`\operatorname{unique}` combinator can be a part of a complex
   query.

   *For each department, show the number of employees and the number of positions.*

   .. code-block:: julia

      department
      :select(
          name,
          count(employee),
          count(unique(employee.position)))

   .. code-block:: julia

      ("WATER MGMNT",1848,154)
      ("POLICE",13570,129)
      ⋮
      ("LICENSE APPL COMM",1,1)


.. slide:: Unique Values with Extra Data
   :level: 2

   Now let us ask for extra information about each position:

   *Show a list of all positions, and, for each position, a list of respective
   employees.*

   We produced a list of all positions:

   .. math::

      \operatorname{unique}(\operatorname{employee}{.}\operatorname{position})

   But how can we relate each position to the respective employees?

   The :math:`\operatorname{unique}` combinator cannot do it.


.. slide:: The :math:`\operatorname{Posn}` Class (1 of 4)
   :level: 3

   *Show a list of all positions, and, for each position, a list of respective
   employees.*

   In this database, employee position is represented as an attribute:

   .. math::

      \operatorname{position} : \operatorname{Empl} \to \operatorname{Text}

   But let us assume, for a moment, that we can change the database schema.

   What if, instead, we represent employee positions as a separate entity
   class:

   .. math::

      \operatorname{Posn}


.. slide:: The :math:`\operatorname{Posn}` Class (2 of 4)
   :level: 3

   *Show a list of all positions, and, for each position, a list of respective
   employees.*

   Suppose employee positions form a separate entity class:

   .. math::

      \operatorname{Posn}

   Then a list of all position entities is produced by a class primitive:

   .. math::

      \operatorname{position} : \operatorname{Void} \to \operatorname{Seq}\{\operatorname{Posn}\}

   Position title becomes an attribute:

   .. math::

      \operatorname{title} : \operatorname{Posn} \to \operatorname{Text}

   Positions and employees are related by a pair of links:

   .. math::

      &\operatorname{position} &: \operatorname{Empl} &\to \operatorname{Posn} \\
      &\operatorname{employee} &: \operatorname{Posn} &\to \operatorname{Seq}\{\operatorname{Empl}\}


.. slide:: The :math:`\operatorname{Posn}` Class (3 of 4)
   :level: 3

   *Show a list of all positions, and, for each position, a list of respective
   employees.*

   Suppose employee positions form an entity class.

   Then we can easily map this query to the schema tree:

   .. graphviz:: citydb-unfolded-position-title-employee-name.dot


.. slide:: The :math:`\operatorname{Posn}` Class (4 of 4)
   :level: 3

   *Show a list of all positions, and, for each position, a list of respective
   employees.*

   Suppose employee positions form an entity class.

   Then this query can be written as follows:

   .. math::

      \operatorname{position}
      {:}\operatorname{select}(\operatorname{title},\operatorname{employee}{.}\operatorname{name})

   Back to reality: there is no class of employee positions.

   Nor are we allowed to modify the schema to add this class.

   Or, perhaps, we are?


.. slide:: Constructing Virtual Entities
   :level: 2

   *Show a list of all positions, and, for each position, a list of respective
   employees.*

   To write this query, we need a "virtual" class of *position* entities.

   It is created with the :math:`\operatorname{group}` combinator:

   .. math::

      \operatorname{group}(\operatorname{employee}, \operatorname{position})

   This combinator is constructed of two components:

   * :math:`\operatorname{employee}`, the base query;
   * :math:`\operatorname{position}`, an expression that partitions the base.

   We commonly write it in pipeline notation:

   .. math::

      \operatorname{employee}{:}\operatorname{group}(\operatorname{position})


.. slide:: Constructing Virtual Entities: Attributes and Links
   :level: 3

   *Show a list of all positions, and, for each position, a list of respective
   employees.*

   We construct "virtual" *position* entities with the
   :math:`\operatorname{group}` combinator:

   .. math::

      \operatorname{group}(\operatorname{employee}, \operatorname{position}) :
      \operatorname{Void} \to \operatorname{Seq}\{\operatorname{Posn}\}

   The :math:`\operatorname{group}` combinator also creates two primitives:

   1. An attribute that relates each position entity to the respective position
      value:

      .. math::

         \operatorname{position} : \operatorname{Posn} \to \operatorname{Text}

   2. A plural link that relates each entity to a list of respective employees:

      .. math::

         \operatorname{employee} : \operatorname{Posn} \to \operatorname{Seq}\{\operatorname{Empl}\}


.. slide:: Using the :math:`\operatorname{group}` Combinator
   :level: 3

   *Show a list of all positions, and, for each position, a list of respective
   employees.*

   Finally, we have all the components necessary for constructing this query:

   .. math::

      &\operatorname{group}(\operatorname{employee}, \operatorname{position}) &:
      \operatorname{Void} &\to \operatorname{Seq}\{\operatorname{Posn}\} \\
      &\operatorname{position} &: \operatorname{Posn} &\to \operatorname{Text} \\
      &\operatorname{employee} &: \operatorname{Posn} &\to \operatorname{Seq}\{\operatorname{Empl}\}

   We write it as follows:

   .. math::

      &\operatorname{employee} \\
      &{:}\operatorname{group}(\operatorname{position}) \\
      &{:}\operatorname{select}(\operatorname{position}, \operatorname{employee}{.}\operatorname{name})


.. slide:: Using the :math:`\operatorname{group}` Combinator: Output
   :level: 3

   *Show a list of all positions, and, for each position, a list of respective
   employees.*

   .. code-block:: julia

      employee
      :group(position)
      :select(
          position,
          employee.name)

   .. code-block:: julia

      ("1ST DEPUTY INSPECTOR GENERAL",["SHARON F"])
      ("A/MGR COM SVC-ELECTIONS",["LAURA G"])
      ("A/MGR OF MIS-ELECTIONS",["TIEN T"])
      ("A/MGR WAREHOUSE-ELECTIONS",["DERRICK H"])
      ⋮
      ("ZONING PLAN EXAMINER",["KYLE B","PETER B","SHOSHA C",…])


