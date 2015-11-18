
push!(LOAD_PATH, "./jl")

using Base.Test
using RBT: Iso, Opt, Seq, Temp, Ctx, CtxTemp, Unit, ifunctor, ofunctor

here = RBT.HerePipe(Int)

@test here(5) == 5

const5 = RBT.ConstPipe(Unit, 5)

@test const5() == 5
@test const5(()) == 5
@test ifunctor(const5) == Iso{Unit}
@test ofunctor(const5) == Iso{Int}

nullint = RBT.NullPipe(Unit)

@test isnull(nullint())

primes = RBT.SetPipe(:primes, Int[2,3,5,7,11])

@test primes() == Int[2,3,5,7,11]

sqmap = RBT.IsoMapPipe(:sq, Dict(1=>1,2=>4,3=>9,4=>16,5=>25,6=>36,7=>49,8=>64,9=>81,10=>100,11=>121))

@test sqmap(5) == 25

decmap = RBT.OptMapPipe(:dec, Dict(2=>1,3=>2,4=>3,5=>4,6=>5,7=>6,8=>7,9=>8))

@test get(decmap(5)) == 4
@test isnull(decmap(1))

divmap = RBT.SeqMapPipe(:div, Dict(4=>[2],6=>[2,3],8=>[2,4],9=>[3],10=>[2,5]))

@test divmap(6) == Int[2,3]
@test divmap(3) == Int[]

@test get((sqmap ^ Opt{Int})(5)) == 25
@test get((sqmap ^ Opt)(5)) == 25
@test (sqmap ^ Seq{Int})(5) == Int[25]
@test (sqmap ^ Seq)(5) == Int[25]
@test (decmap ^ Seq)(5) == Int[4]
@test (decmap ^ Seq)(1) == Int[]

@test (Temp ^ sqmap)(5) == 25
@test (Temp ^ sqmap)(Temp{Int}([3,5,7], 2)) == 25

typealias CtxX{T} Ctx{(:x,),Tuple{Int},T}
typealias CtxXY{T} Ctx{(:x,:y),Tuple{Int,Int},T}
typealias CtxTempXY{T} CtxTemp{(:x,:y),Tuple{Int,Int},T}

@test (CtxXY ^ sqmap)(CtxXY{Int}(5, (0,1))) == 25
@test (CtxXY ^ sqmap)(5, x=0, y=1) == 25
@test (CtxXY ^ (CtxX ^ sqmap))(5, x=0, y=1) == 25
@test (CtxTempXY ^ (CtxX ^ sqmap))(5, x=0, y=1) == 25
@test (CtxTempXY ^ (Temp ^ sqmap))(5, x=0, y=1) == 25

@test (primes >> sqmap)() == [4,9,25,49,121]
@test (primes >> decmap)() == [1,2,4,6]
@test (primes >> divmap)() == []

@test (const5 * const5)() == (5, 5)
@test get((sqmap * decmap)(5)) == (25, 4)
@test (divmap * decmap)(6) == [(2, 5), (3, 5)]

X = RBT.IsoParamPipe(Unit, :x, Int)
Y = RBT.OptParamPipe(Unit, :y, Int)
Z = RBT.SeqParamPipe(Unit, :z, Int)

Item1 = RBT.ItemPipe(Tuple{Int,Int}, 1)
Item2 = RBT.ItemPipe(Tuple{Int,Int}, 2)

XY = (X * Y) >> RBT.MulPipe(Item1, Item2)
XYZ = (X * ((Y * Z) >> RBT.MulPipe(Item1, Item2))) >> RBT.MulPipe(Item1, Item2)

@test X((); x=5) == 5
@test get(XY((); x=5, y=Nullable(7))) == 35
@test isnull(XY((); x=5, y=Nullable{Int}()))
@test XYZ((); x=4, y=Nullable(5), z=[1,2,3]) == [20, 40, 60]

primes_next = primes >> RBT.NextPipe(Int, 1)
primes_next_next = primes_next >> RBT.NextPipe(Int, 1)
primes_next_prev = primes_next >> RBT.NextPipe(Int, -1)
primes_future = primes >> RBT.FuturePipe(Int, 1)
primes_past = primes >> RBT.FuturePipe(Int, -1)

@test primes() == [2, 3, 5, 7, 11]
@test primes_next() == [3, 5, 7, 11]
@test primes_next_next() == [5, 7, 11]
@test primes_next_prev() == [3, 5, 7]
@test primes_future() == [3,5,7,11,5,7,11,7,11,11]
@test primes_past() == [2,3,2,5,3,2,7,5,3,2]


