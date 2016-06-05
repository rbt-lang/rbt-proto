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

   What is the signature of :math:`\operatorname{sort}(Q)`?  Suppose, :math:`Q`
   is any plural query:

   .. math::

      Q : A \to \operatorname{Seq}\{B\}

   Then query :math:`\operatorname{sort}(Q)` retains the signature of
   :math:`Q`:

   .. math::

      \operatorname{sort}(Q) : A \to \operatorname{Seq}\{B\}


.. slide:: Sorting by Key
   :level: 3

   Consider a similar query:

   *Show all employees ordered by salary.*

   We can produce an ordered list of salaries.

   .. code-block:: julia

      sort(employee.salary)

   .. code-block:: julia

      1
      2756
      2756
      2756
      ⋮
      260004

   Can we see employee names too?


.. slide:: Sorting by Key: Output
   :level: 3

   *Show all employees ordered by salary.*

   The :math:`\operatorname{sort}` combinator lets you specify a sort key as
   its second parameter:

   .. math::

      \operatorname{sort}(\operatorname{employee}, \operatorname{salary})

   It is usually written in pipeline notation:

   .. code-block:: julia

      employee:sort(salary)

   .. code-block:: julia

      ("STEVEN K","MAYOR'S OFFICE","ADMINISTRATIVE SECRETARY",1)
      ("BETTY A","FAMILY & SUPPORT","FOSTER GRANDPARENT",2756)
      ("VICTOR A","FAMILY & SUPPORT","SENIOR COMPANION",2756)
      ("RASHEEDAH A","FAMILY & SUPPORT","SENIOR COMPANION",2756)
      ⋮
      ("GARRY M","POLICE","SUPERINTENDENT OF POLICE",260004)


.. slide:: Sort Order
   :level: 3

   Can we show the highest paid employees first?

   *Show all employees ordered by salary in descending order.*

   Use the :math:`\operatorname{desc}` indicator.

   .. code-block:: julia

      employee:sort(salary:desc)

   .. code-block:: julia

      ("GARRY M","POLICE","SUPERINTENDENT OF POLICE",260004)
      ("RAHM E","MAYOR'S OFFICE","MAYOR",216210)
      ("JOSE S","FIRE","FIRE COMMISSIONER",202728)
      ("CHARLES S","FIRE","FIRST DEPUTY FIRE COMMISSIONER",197736)
      ⋮
      ("STEVEN K","MAYOR'S OFFICE","ADMINISTRATIVE SECRETARY",1)

   :math:`\operatorname{desc}(K)` does not change the value of :math:`K`, but
   reverses the sort order.


.. slide:: Sorting by Key: Signature
   :level: 3

   The general form of the :math:`\operatorname{sort}` combinator:

   .. math::

      \operatorname{sort}(Q, K_1, K_2, \ldots, K_n)

   Here, :math:`Q` is any plural query:

   .. math::

      Q : A \to \operatorname{Seq}\{B\}

   Sort keys operate on values of :math:`Q`:

   .. math::

      K_k : B \to C_k \quad (k=1,2,\ldots,n)

   :math:`\operatorname{sort}` preserves the interface of its plural component:

   .. math::

      \operatorname{sort}(Q, K_1, K_2, \ldots, K_n) : A \to \operatorname{Seq}\{B\}


.. slide:: Sorting by Key: Example
   :level: 3

   A sorting key can be a complex expression.  Example:

   *Show all departments ordered by the number of employees, largest first.*

   .. code-block:: julia

      department
      :sort(count(employee):desc)
      :select(name, count(employee))

   .. code-block:: julia

      ("POLICE",13570)
      ("FIRE",4875)
      ⋮
      ("LICENSE APPL COMM",1)


.. slide:: Slicing
   :level: 2

   Combinators :math:`\operatorname{take}` and :math:`\operatorname{skip}`
   can extract a slice of the output sequence.

   Example:

   *Show the first 4 departments.*

   .. code-block:: julia

      department:take(4)

   .. code-block:: julia

      ("WATER MGMNT",)
      ("POLICE",)
      ("GENERAL SERVICES",)
      ("CITY COUNCIL",)


.. slide:: Slicing: :math:`\operatorname{take}` and :math:`\operatorname{skip}`
   :level: 3

   *Show all but the first 10 departments.*

   .. code-block:: julia

      department:skip(10)

   .. code-block:: julia

      ("DoIT",)
      ("BUSINESS AFFAIRS",)
      ⋮
      ("LICENSE APPL COMM",)

   *Show departments from 10th to 14th.*

   .. code-block:: julia

      department:skip(10):take(4)

   .. code-block:: julia

      ("DoIT",)
      ("BUSINESS AFFAIRS",)
      ("OEMC",)
      ("TRANSPORTN",)


.. slide:: Slicing: Signature
   :level: 3

   Slicing combinators have the form:

   .. math::

      \operatorname{take}(Q,N) \qquad
      \operatorname{skip}(Q,N)

   * :math:`Q` is any plural query:

     .. math::

        Q : A \to \operatorname{Seq}\{B\}

   * :math:`N` is an integer-valued query with the same input as :math:`Q`:

     .. math::

        N : A \to \operatorname{Int}

   The combinators preserve the interface of their plural component:

   .. math::

      &\operatorname{take}(Q,N) &: A &\to \operatorname{Seq}\{B\} \\
      &\operatorname{skip}(Q,N) &: A &\to \operatorname{Seq}\{B\}


.. slide:: Slicing: Examples
   :level: 3

   Size of the slice does not have to be a constant.  Example:

   *Show a half of all departments.*

   .. code-block:: julia

      department
      :take(count(department)/2)

   In a pipeline, :math:`{:}\operatorname{take}` is usually placed after
   :math:`{:}\operatorname{sort}`.  Example:

   *Show the top 3 largest departments.*

   .. code-block:: julia

      department
      :define(size => count(employee))
      :sort(size:desc)
      :take(3)
      :select(name, size)


.. slide:: Other Sequence Combinators
   :level: 2

   * Combinator :math:`\operatorname{reverse}` reverses the sequence.

     *Show departments in the reverse order.*

     .. math::

        \operatorname{department}{:}\operatorname{reverse}

   * Combinator :math:`\operatorname{first}` picks the first element of the
     sequence.

     *Show the first department.*

     .. math::

        \operatorname{department}{:}\operatorname{first}

   * Combinator :math:`\operatorname{first}` can be provided with a sort key.

     *Show the largest department.*

     .. math::

        \operatorname{department}
        {:}\operatorname{first}(\operatorname{count}(\operatorname{employee}))


.. slide:: Signature of the :math:`\operatorname{first}` Combinator
   :level: 3

   The general form of the :math:`\operatorname{first}` combinator:

   .. math::

      \operatorname{first}(Q, K_1, K_2, \ldots, K_n)

   * :math:`Q` is any plural query:

     .. math::

        Q : A \to \operatorname{Seq}\{B\}

   * Sort keys operate on values of :math:`Q`:

     .. math::

        K_k : B \to C_k \quad (k=1,2,\ldots,n)

   :math:`\operatorname{first}` preserves the type of the output of :math:`Q`,
   but changes its cardinality:

   .. math::

      \operatorname{first}(Q, K_1, K_2, \ldots, K_n) : A \to \operatorname{Opt}\{B\}


