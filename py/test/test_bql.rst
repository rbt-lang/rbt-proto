JSON Combinators
================

We start with importing the sample dataset and the combinators library::

    >>> import sys
    >>> sys.path.append('./py')

    >>> from citydb_json import citydb
    >>> from bql import *
    >>> from pprint import pprint

A JSON combinator is a function that maps JSON values to JSON values.  The
constant combinator always returns the same value::

    >>> C = Const(42)
    >>> C(citydb)
    42

The identity combinator returns its input unchanged::

    >>> I = This()
    >>> I(42)
    42

The ``Field()`` combinator extracts field values from JSON objects::

    >>> Departments = Field('departments')
    >>> Departments(citydb)     # doctest: +ELLIPSIS
    [...]

The ``Select()`` combinator constructs JSON objects::

    >>> O = Select(x=Const(42))
    >>> O(citydb)
    {'x': 42}

Use the composition combinator to build complex queries from elementary
combinators.  Here, we combine two field extractors to get a list of department
names::

    >>> Name = Field('name')
    >>> Department_Names = Departments >> Name
    >>> Department_Names(citydb)        # doctest: +ELLIPSIS
    [..., 'POLICE', ...]

Use the ``Count()`` aggregate to count things::

    >>> Num_Dept = Count(Departments)
    >>> Num_Dept(citydb)
    35

Combine different combinators to construct interesting queries::

    >>> Employees = Field('employees')
    >>> Departments_With_Num_Empl = Departments >> Select(name=Name, num_empl=Count(Employees))
    >>> departments_with_num_empl = Departments_With_Num_Empl(citydb)
    >>> pprint(departments_with_num_empl)       # doctest: +ELLIPSIS, +NORMALIZE_WHITESPACE
    [..., {'name': 'POLICE', 'num_empl': 13570}, ...]

