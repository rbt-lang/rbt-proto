"""
A mini-query language for JSON data.

The query language is embedded in Python so that each query is a Python
function that maps a JSON value to a JSON value.  Such functions are called
*JSON combinators*.

Elementary JSON combinators include constants, the identity combinator,
combinators for constructing JSON objects and extracting object fields, as well
as common functions and operators:

``Const(val)``
    Always produces ``val``.
``This()``
    Identity combinator.
``Field(name)``
    Extracts a field value from a JSON object.
``Select(name=..., ...)``
    Generates a JSON with the given fields.

Composition operator lets you build complex queries from elementary
combinators.  Combinator ``(F >> G)`` sends its input first through ``F`` and
then ``G``; the output of ``G`` becomes the output of ``(F >> G)``.  If ``F``
returns an array value, ``G`` is applied to each element of the array, in which
case, the output of ``(F >> G)`` is an array composed of all outputs of ``G``.

Examples::

    >>> Departments, Employees, Name, Size, Salary = \
    ...     Fields('departments', 'employees', 'name', 'size', 'salary')

    >>> Department_Names = Departments >> Names

    >>> Departments_with_Size = \
    ...     Departments >> Select(name=Name, size=Count(Employees))

    >>> Large_Departments = \
    ...     Departments_with_Size >> Filter(Size > 1000)

    >>> Departments_With_Max_Salary = \
    ...     Departments >> Select(name=Name, max_salary=Max(Employees >> Salary))
"""


import operator


try:
    long
except NameError:
    long = int
try:
    unicode
except NameError:
    unicode = str


class IllegalInputError(ValueError):

    def __init__(self, F, x):
        self.F = F
        self.x = x

    def __str__(self):
        x = repr(self.x)
        if len(x) > 32:
            x = x[:32-3]+'...'
        return "%r(%s)" % (self.F, x)


class IllegalOperandsError(ValueError):

    def __init__(self, F, *ys):
        self.F = F
        self.ys = ys

    def __str__(self):
        ys = []
        for y in self.ys:
            y = repr(y)
            if len(y) > 32:
                y = y[:32-3]+'...'
            ys.append(y)
        ys = ", ".join(ys)
        return "%r: %s" % (self.F, ys)


class IllegalContextError(ValueError):

    def __init__(self, F):
        self.F = F

    def __str__(self):
        return repr(self.F)


class Combinator(object):

    def __repr__(self):
        return "%s()" % self.__class__.__name__

    def __call__(self, x, ctx={}):
        raise IllegalInputError(self, x)

    def refs(self):
        return set()

    def __lt__(self, other):
        if not isinstance(other, Combinator):
            other = Const(other)
        return LT(self, other)

    def __le__(self, other):
        if not isinstance(other, Combinator):
            other = Const(other)
        return LE(self, other)

    def __eq__(self, other):
        if not isinstance(other, Combinator):
            other = Const(other)
        return EQ(self, other)

    def __ne__(self, other):
        if not isinstance(other, Combinator):
            other = Const(other)
        return NE(self, other)

    def __gt__(self, other):
        if not isinstance(other, Combinator):
            other = Const(other)
        return GT(self, other)

    def __ge__(self, other):
        if not isinstance(other, Combinator):
            other = Const(other)
        return GE(self, other)

    def __add__(self, other):
        if not isinstance(other, Combinator):
            other = Const(other)
        return Add(self, other)

    def __sub__(self, other):
        if not isinstance(other, Combinator):
            other = Const(other)
        return Sub(self, other)

    def __mul__(self, other):
        if not isinstance(other, Combinator):
            other = Const(other)
        return Mul(self, other)

    def __div__(self, other):
        if not isinstance(other, Combinator):
            other = Const(other)
        return Div(self, other)

    def __mod__(self, other):
        if not isinstance(other, Combinator):
            other = Const(other)
        return Mod(self, other)

    def __rshift__(self, other):
        if not isinstance(other, Combinator):
            other = Const(other)
        return RShift(self, other)

    def __and__(self, other):
        if not isinstance(other, Combinator):
            other = Const(other)
        return And(self, other)

    def __or__(self, other):
        if not isinstance(other, Combinator):
            other = Const(other)
        return Or(self, other)

    def __xor__(self, other):
        if not isinstance(other, Combinator):
            other = Const(other)
        return XOr(self, other)

    def __radd__(self, other):
        if not isinstance(other, Combinator):
            other = Const(other)
        return Add(other, self)

    def __rsub__(self, other):
        if not isinstance(other, Combinator):
            other = Const(other)
        return Sub(other, self)

    def __rmul__(self, other):
        if not isinstance(other, Combinator):
            other = Const(other)
        return Mul(other, self)

    def __rdiv__(self, other):
        if not isinstance(other, Combinator):
            other = Const(other)
        return Div(other, self)

    def __rmod__(self, other):
        if not isinstance(other, Combinator):
            other = Const(other)
        return Mod(other, self)

    def __rrshift__(self, other):
        if not isinstance(other, Combinator):
            other = Const(other)
        return RShift(other, self)

    def __rand__(self, other):
        if not isinstance(other, Combinator):
            other = Const(other)
        return And(other, self)

    def __ror__(self, other):
        if not isinstance(other, Combinator):
            other = Const(other)
        return Or(other, self)

    def __rxor__(self, other):
        if not isinstance(other, Combinator):
            other = Const(other)
        return XOr(other, self)

    def __neg__(self):
        return Neg(self)

    def __pos__(self):
        return Pos(self)

    def __invert__(self):
        return Invert(self)


class Const(Combinator):

    def __init__(self, value):
        self.value = value

    def __repr__(self):
        return "%s(%r)" % (self.__class__.__name__, self.value)

    def __call__(self, x, ctx={}):
        return self.value


class This(Combinator):

    def __call__(self, x, ctx={}):
        return x


class Field(Combinator):

    def __init__(self, name):
        self.name = name

    def __repr__(self):
        return "%s(%r)" % (self.__class__.__name__, self.name)

    def __call__(self, x, ctx={}):
        if isinstance(x, dict) and self.name in x:
            return x[self.name]
        raise IllegalInputError(self, x)


def Fields(*names):
    for name in names:
        yield Field(name)


class Ref(Combinator):

    def __init__(self, name):
        self.name = name

    def __repr__(self):
        return "%s(%r)" % (self.__class__.__name__, self.name)

    def __call__(self, x, ctx={}):
        if self.name in ctx:
            return ctx[self.name]
        raise IllegalContextError(self)

    def refs(self):
        return set([self.name])


def Refs(*names):
    for name in names:
        yield Ref(name)


class Compose(Combinator):

    def __init__(self, *Fs):
        self.Fs = Fs

    def __repr__(self):
        return " >> ".join(map(repr, self.Fs))

    def __call__(self, x, ctx={}):
        for F in self.Fs:
            if x is None:
                y = None
            elif isinstance(x, list):
                y = []
                for yi in map(lambda x: F(x, ctx), x):
                    if isinstance(yi, list):
                        y.extend(yi)
                    elif yi is not None:
                        y.append(yi)
            else:
                y = F(x, ctx)
            x = y
        return x

    def refs(self):
        refs = set()
        for F in self.Fs:
            refs |= F.refs()
        return refs


def RShift(F, G):
    Fs = []
    for H in (F, G):
        if isinstance(H, Compose):
            Fs.extend(H.Fs)
        else:
            Fs.append(H)
    return Compose(*Fs)


class Select(Combinator):

    def __init__(self, **name_to_F):
        self.name_to_F = name_to_F

    def __repr__(self):
        args = ["%s=%r" % item for item in sorted(self.name_to_F.items())]
        return "%s(%s)" % (self.__class__.__name__, ", ".join(args))

    def __call__(self, x, ctx={}):
        y = {}
        for name, F in sorted(self.name_to_F.items()):
            y[name] = F(x, ctx)
        return y

    def refs(self):
        refs = set()
        for name, F in sorted(self.name_to_F.items()):
            refs |= F.refs()
        return refs


class Given(Combinator):

    def __init__(self, F, **name_to_F):
        self.F = F
        self.name_to_F = name_to_F

    def __repr__(self):
        args = [repr(self.F)]
        args.extend("%s=%r" % item for item in sorted(self.name_to_F.items()))
        return "%s(%s)" % (self.__class__.__name__, ", ".join(args))

    def __call__(self, x, ctx={}):
        new_ctx = ctx.copy()
        for name, F in sorted(self.name_to_F.items()):
            new_ctx[name] = F(x, ctx)
        return self.F(x, new_ctx)

    def refs(self):
        return self.F.refs() - set(self.name_to_F)


class UnaryOp(Combinator):

    op = None
    types = []

    def __init__(self, F):
        self.F = F

    def __repr__(self):
        return "%s(%r)" % (self.__class__.__name__, self.F)

    def __call__(self, x, ctx={}):
        y = self.F(x, ctx)
        if y is None:
            return None
        if isinstance(y, list):
            return [self.apply(yi) for yi in y]
        return self.apply(y)

    def apply(self, y):
        for type in self.types:
            if isinstance(y, type):
                return self.op(y)
        raise IllegalOperandsError(self, y)

    def refs(self):
        return self.F.refs()


class BinaryOp(Combinator):

    op = None
    types = []

    def __init__(self, F, G):
        self.F = F
        self.G = G

    def __repr__(self):
        return "%s(%r, %r)" % (self.__class__.__name__, self.F, self.G)

    def __call__(self, x, ctx={}):
        y = self.F(x, ctx)
        z = self.G(x, ctx)
        if y is None or z is None:
            return None
        if isinstance(y, list) and not isinstance(z, list):
            return [self.apply(yi, z) for yi in y]
        if not isinstance(y, list) and isinstance(z, list):
            return [self.apply(y, zi) for zi in z]
        return self.apply(y, z)

    def apply(self, y, z):
        for type in self.types:
            if isinstance(y, type) and isinstance(z, type):
                return self.op(y, z)
        raise IllegalOperandsError(self, y, z)

    def refs(self):
        return self.F.refs() | self.G.refs()


class Filter(UnaryOp):

    def __call__(self, x, ctx={}):
        y = self.F(x, ctx)
        if y is None or y is False:
            return None
        if y is True:
            return x
        raise IllegalOperandsError(self, y)


class Len(UnaryOp):

    op = len
    types = [(str, unicode)]


class Neg(UnaryOp):

    op = operator.neg
    types = [(int, long, float)]


class Pos(UnaryOp):

    op = operator.pos
    types = [(int, long, float)]


class Invert(UnaryOp):

    op = operator.invert
    types = [bool]


class Connective(BinaryOp):

    types = [bool]


class And(Connective):

    op = operator.and_


class Or(Connective):

    op = operator.or_


class XOr(Connective):

    op = operator.xor


class Comparison(BinaryOp):

    types = [(int, long, float), (str, unicode)]


class LT(Comparison):

    op = operator.lt


class LE(Comparison):

    op = operator.le


class EQ(Comparison):

    op = operator.eq


class NE(Comparison):

    op = operator.ne


class GT(Comparison):

    op = operator.gt


class GE(Comparison):

    op = operator.ge


class Add(BinaryOp):

    @staticmethod
    def op(p, q):
        if isinstance(p, dict) and isinstance(q, dict):
            r = {}
            r.update(p)
            r.update(q)
            return r
        return p+q

    types = [(int, long, float), (str, unicode), list, dict]


class Sub(BinaryOp):

    op = operator.sub
    types = [(int, long, float)]


class Div(BinaryOp):

    op = operator.truediv
    types = [(int, long, float)]


class Mod(BinaryOp):

    op = operator.mod
    types = [(int, long, float)]


class Count(UnaryOp):

    def __call__(self, x, ctx={}):
        y = self.F(x, ctx)
        if isinstance(y, list):
            return len(y)
        raise IllegalOperandsError(self, y)


class MinMaxOp(UnaryOp):

    types = [(int, long, float, str, unicode)]

    def __call__(self, x, ctx={}):
        y = self.F(x, ctx)
        if y == []:
            return None
        for type in self.types:
            if isinstance(y, list) and all(isinstance(yi, type) for yi in y):
                return self.op(y)
        raise IllegalOperandsError(self, y)


class Min(MinMaxOp):

    op = min


class Max(MinMaxOp):

    op = max


class First(Combinator):

    def __init__(self, F, N=None):
        self.F = F
        self.N = N

    def __repr__(self):
        if self.N is None:
            return "%s(%r)" % (self.__class__.__name__, self.F)
        else:
            return "%s(%r, %r)" % (self.__class__.__name__, self.F, self.N)

    def __call__(self, x, ctx={}):
        y = self.F(x, ctx)
        N = self.N
        if isinstance(N, Combinator):
            N = N(x, ctx)
        if y == [] and N is None:
            return None
        if isinstance(y, list):
            if N is None:
                return y[0]
            elif isinstance(N, (int, long)):
                return y[:N]
        raise IllegalOperandsError(self, y)

    def refs(self):
        refs = self.F.refs()
        if isinstance(self.N, Combinator):
            refs = refs | self.N.refs()
        return refs

