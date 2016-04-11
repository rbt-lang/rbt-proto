Unfolding a Schema
==================


.. slide:: Querying Non-Hierarchical Databases
   :level: 2

   Our progress so far:

   * We consider hierarchical databases, with data organized in a tree
     structure.

   * Then *a query* maps one tree structure to another.

   * *Combinators* provide a declarative way to compose complex queries.

   * Powerful and easy to use, when it works.

   Example:

   .. code-block:: julia

        Depts_With_Num_Well_Paid_Empls =
            Departments >> Select(
                "name" => Name,
                "N100k" => Count(Employees >> Sieve(Salary > 100000)))


.. slide:: Querying Non-Hierarchical Databases: Idea
   :level: 3

   However, query combinators have major limitations:

   * Input data must be hierarchical.

   * Structure of the query must respect structure of the data.

   Can we generalize query combinators to non-hierarchical databases?

   Wrong question!  Instead, let us ask:

   *Can we make any database hierarchical?*

   Then use combinators to query it.


.. slide:: Categorical Data Model
   :level: 2

   Recall *categorical data model:*

   * Objects: value and entity types.
   * Arrows: attributes and relationships.

   Example (textbook "employees & departments" schema):

   .. graphviz:: citydb-functional-data-model.dot


.. slide:: Categorical Data Model: Composing Arrows
   :level: 3

   Arrows with compatible input and output can be composed.

   For example, take:

   .. math::

      &\operatorname{department} & : \operatorname{Empl}&\to\operatorname{Dept} \\
      &\operatorname{name} & : \operatorname{Dept}&\to\operatorname{Text}

   Composing them, we get:

   .. math::

      \operatorname{department}{.}\operatorname{name}: \operatorname{Empl} \to \operatorname{Text}

   This is a query that maps an employee entity to the name of their
   department.


.. slide:: Categorical Data Model: Limitations
   :level: 3

   Categorical data model is simple and straightforward.  It is also
   inadequate:

   Not every relationship can be represented as an arrow between entity types.

   Consider:

   * Relationship that associates every department to the set of the respective
     employees.

   * Relationship that associates every employee to their manager.


.. slide:: Plural Relationships
   :level: 3

   Consider a relationship:

   *A department is associated with the respective employees.*

   This is inverse to the arrow:

   .. math::

      \operatorname{department} : \operatorname{Empl}\to\operatorname{Dept}

   What is the signature of this new relationship?  Perhaps:

   .. math::

      \operatorname{employee} : \operatorname{Dept}\to\operatorname{Empl}\;?

   No, because for a given department, there are multiple employees.

   This is *a plural relationship*.


.. slide:: Partial Relationships
   :level: 3

   Consider a relationship:

   *An employee is associated with their manager.*

   What is the signature if this relationship?

   .. math::

      \operatorname{managed\_by} : \operatorname{Empl}\to\operatorname{Empl}\;?

   But not every employee has a manager! (The CEO doesn't).

   This is *a partial relationship*.


.. slide:: Expressing Plural and Partial Relationships
   :level: 2

   In the present form, categorical data model cannot express plural and
   partial relationships.

   But it seems easy to mend.  Introduce parametric types:

   * :math:`\operatorname{Seq}\{T\}` is a finite sequence of values of type
     :math:`T`.

   * :math:`\operatorname{Opt}\{T\}` is zero or one value of type :math:`T`.

   Then define:

   .. math::

      &\operatorname{employee} & : \operatorname{Dept}&\to\operatorname{Seq}\{\operatorname{Empl}\} \\
      &\operatorname{managed\_by} & : \operatorname{Empl}&\to\operatorname{Opt}\{\operatorname{Empl}\}

   Are we good now?


.. slide:: Expressing Plural and Partial Relationships: Composition
   :level: 3

   Unfortunately, we lost the ability to compose arrows.  Consider:

   .. math::

      &\operatorname{employee} & : \operatorname{Dept}&\to\operatorname{Seq}\{\operatorname{Empl}\} \\
      &\operatorname{name} & : \operatorname{Empl}&\to\operatorname{Text}

   Or:

   .. math::

      &\operatorname{managed\_by} & : \operatorname{Empl}&\to\operatorname{Opt}\{\operatorname{Empl}\} \\
      &\operatorname{salary} & : \operatorname{Empl}&\to\operatorname{Int}

   Inputs and outputs do not agree, so we cannot form compositions:

   .. math::

      \operatorname{employee}{.}\operatorname{name}, \quad
      \operatorname{managed\_by}{.}\operatorname{salary}.

   Can we give a meaning to these expressions?


.. slide:: Monadic Composition
   :level: 3

   A parametric type :math:`M\{T\}` is *a monad* if for any mappings:

   .. math::

      f : A \to M\{B\}, \quad
      g : B \to M\{C\}

   there is a monadic composition:

   .. math::

      f{.}g : A \to M\{C\}.

   Both :math:`\operatorname{Opt}\{T\}` and :math:`\operatorname{Seq}\{T\}`
   are monads!


.. slide:: Monadic Composition: :math:`\operatorname{Opt}\{T\}`
   :level: 3

   Given:

   .. math::

      f : A \to \operatorname{Opt}\{B\}, \quad
      g : B \to \operatorname{Opt}\{C\}

   Define:

   .. math::

      f{.}g : A \to \operatorname{Opt}\{C\} :
      x \mapsto \begin{cases}
        \operatorname{null} & (f(x)=\operatorname{null}) \\
        g(f(x)) & (f(x)\ne\operatorname{null})
      \end{cases}

   This is just a composition of partial functions.


.. slide:: Monadic Composition: :math:`\operatorname{Seq}\{T\}`
   :level: 3

   Given:

   .. math::

      f : A \to \operatorname{Seq}\{B\}, \quad
      g : B \to \operatorname{Seq}\{C\}

   Define:

   .. math::
      :nowrap:

      \begin{gather}
      f{.}g : A \to \operatorname{Seq}\{C\} :
      x \mapsto [z_{11}, z_{12}, \ldots, z_{21}, z_{22}, \ldots], \\
      \text{where } f(x) = [y_1, y_2, \ldots],\; g(y_k) = [z_{k1}, z_{k2}, \ldots]
      \end{gather}

   Evaluating :math:`f(x)`, we get some sequence :math:`[y_1, y_2, \ldots]`.
   We apply :math:`g` to every element of the sequence, then flatten the
   result.


.. slide:: Composition: Embedding
   :level: 3

   We need one more composition rule: How to compose arrows of different kinds?

   For example:

   .. math::

      f : A \to \operatorname{Opt}\{B\}, \quad
      g : B \to \operatorname{Seq}\{C\}.

   Consider:

   * :math:`T` contains exactly one value.
   * :math:`\operatorname{Opt}\{T\}` contains zero or one value.
   * :math:`\operatorname{Seq}\{T\}` contains zero, one or more values.

   This gives us natural embedding:

   .. math::

      T \hookrightarrow \operatorname{Opt}\{T\} \hookrightarrow \operatorname{Seq}\{T\}


.. slide:: Composition: Example
   :level: 3

   With monadic composition and embedding rules, we can compose any mappings
   with compatible inputs and outputs.

   For example, consider:

   .. math::

      &\operatorname{employee} & : \operatorname{Dept}&\to\operatorname{Seq}\{\operatorname{Empl}\} \\
      &\operatorname{name} & : \operatorname{Empl}&\to\operatorname{Text}

   First, lift the output of :math:`\operatorname{name}` to
   :math:`\operatorname{Seq}\{\operatorname{Text}\}`:

   .. math::

      \operatorname{Empl}\overset{\operatorname{name}}{\longrightarrow}\operatorname{Text}
      \hookrightarrow\operatorname{Seq}\{\operatorname{Text}\}

   Then, use monadic composition for :math:`\operatorname{Seq}\{T\}`.  We get:

   .. math::

      \operatorname{employee}{.}\operatorname{name} :
      \operatorname{Dept} \to \operatorname{Seq}\{\operatorname{Text}\}


.. slide:: Class Arrows
   :level: 2

   Database schema describes entity classes as objects:

   .. math::

      \operatorname{Dept}, \quad \operatorname{Empl}

   Can we also describe them as arrows?

   What would be a signature of a class arrow?

   .. math::

      &\operatorname{department} & : (?)&\to\operatorname{Seq}\{\operatorname{Dept}\} \\
      &\operatorname{employee} & : (?)&\to\operatorname{Seq}\{\operatorname{Empl}\}

   Output: a sequence of all entities of a particular type.

   But what is the input?


.. slide:: Class Arrows: Singleton Type
   :level: 3

   Let us introduce *a singleton type* (type with a single value):

   .. math::

      \operatorname{Void} \quad (\operatorname{nothing}\in\operatorname{Void})

   Singleton type serves as input for class arrows:

   .. math::

      &\operatorname{department} & : \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Dept}\} \\
      &\operatorname{employee} & : \operatorname{Void}&\to\operatorname{Seq}\{\operatorname{Empl}\}

   Class arrows map :math:`\operatorname{nothing}` (the only value of the
   :math:`\operatorname{Void}` type) to a sequence of all departments and
   employees respectively.


.. slide:: Unfolding a Database Schema
   :level: 2

   The problem: *Can we make any database hierarchical?*

   We can now solve it: Start with :math:`\operatorname{Void}` type; then
   follow all arrows.

   We get unfolded database schema:

   .. graphviz:: citydb-unfolded-data-model.dot


