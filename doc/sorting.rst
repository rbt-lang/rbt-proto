Sorting and Slicing
===================


.. slide:: Operations on Sequences
   :level: 2

   A *plural* query produces a sequence of values.  Example:

   .. math::

      \operatorname{employee}:\operatorname{Void}\to\operatorname{Seq}\{\operatorname{Empl}\}

   A *sequence* combinator operates on plural queries and:

   * preserves the values of the output sequence;
   * rearranges the sequence itself.

   Example:

   .. math::

      \operatorname{employee}{:}\operatorname{filter}(\operatorname{salary}>100000):
      \operatorname{Void}\to\operatorname{Seq}\{\operatorname{Empl}\}

   In this section, we discuss sequence combinators for:

   * sorting data;
   * slicing data.


.. slide:: Sorting
   :level: 2

   We learned how to extract data from the database.

   *Show the names of all departments.*

   .. code-block:: julia

      department.name

   .. code-block:: julia

      "WATER MGMNT"
      "POLICE"
      ⋮
      "LICENSE APPL COMM"

   Now consider a query:

   *Show the names of all departments in alphabetical order.*

   Can we implement it?


.. slide:: The :math:`\operatorname{sort}` Combinator
   :level: 3

   *Show the names of all departments.*

   .. math::

      \operatorname{department}{.}\operatorname{name}

   *Show the names of all departments in alphabetical order.*

   Use the :math:`\operatorname{sort}` combinator:

   .. math::

      \operatorname{sort}(\operatorname{department}{.}\operatorname{name})

   We can also write it in pipeline form:

   .. math::

      \operatorname{department}{.}\operatorname{name}{:}\operatorname{sort}


.. slide:: The :math:`\operatorname{sort}` Combinator: Output and Signature
   :level: 3

   *Show the names of all departments in alphabetical order.*

   .. code-block:: julia

      sort(department.name)

   .. code-block:: julia

      "ADMIN HEARNG"
      "ANIMAL CONTRL"
      ⋮
      "WATER MGMNT"

   What is the signature of :math:`\operatorname{sort}(Q)`?  Suppose :math:`Q`
   is any plural query:

   .. math::

      Q : A \to \operatorname{Seq}\{B\}

   Then query :math:`\operatorname{sort}(Q)` has the same interface as
   :math:`Q`:

   .. math::

      \operatorname{sort}(Q) : A \to \operatorname{Seq}\{B\}


