
push!(LOAD_PATH, "./jl")

using Base.Test
using RBT: Temp, Ctx, Opt, Seq

typealias UNIT Tuple{}

here = RBT.HerePipe{Int}()

@test here(5) == 5

const5 = RBT.ConstPipe{UNIT,Int}(5)

@test const5() == 5
@test const5(()) == 5

nullint = RBT.NullPipe{UNIT,Int}()

@test isnull(nullint())

primes = RBT.SetPipe{UNIT,Int}(:primes, Int[2,3,5,7,11])

@test primes() == Int[2,3,5,7,11]

sqmap = RBT.IsoMapPipe{Int,Int}(:sq, Dict(1=>1,2=>4,3=>9,4=>16,5=>25,6=>36,7=>49,8=>64,9=>81,10=>100,11=>121))

@test sqmap(5) == 25

decmap = RBT.OptMapPipe{Int,Int}(:dec, Dict(2=>1,3=>2,4=>3,5=>4,6=>5,7=>6,8=>7,9=>8))

@test get(decmap(5)) == 4
@test isnull(decmap(1))

divmap = RBT.SeqMapPipe{Int,Int}(:div, Dict(4=>[2],6=>[2,3],8=>[2,4],9=>[3],10=>[2,5]))

@test divmap(6) == Int[2,3]
@test divmap(3) == Int[]

@test get(RBT.LiftPipe{Int,Int,Int,Opt{Int}}(sqmap)(5)) == 25
@test RBT.LiftPipe{Int,Int,Int,Seq{Int}}(sqmap)(5) == Int[25]
@test RBT.LiftPipe{Int,Int,Opt{Int},Seq{Int}}(decmap)(5) == Int[4]
@test RBT.LiftPipe{Int,Int,Opt{Int},Seq{Int}}(decmap)(1) == Int[]

@test RBT.LiftPipe{Int,Temp{Int},Int,Int}(sqmap)(Temp{Int}([5], 1)) == 25
@test RBT.LiftPipe{Int,Temp{Int},Int,Int}(sqmap)(5) == 25
@test RBT.LiftPipe{Int,Ctx{Int,(:x,:y),Tuple{Int,Int}},Int,Int}(sqmap)(Ctx{Int,(:x,:y),Tuple{Int,Int}}(5, (0,1))) == 25
@test RBT.LiftPipe{Int,Ctx{Int,(:x,:y),Tuple{Int,Int}},Int,Int}(sqmap)(5, x=0, y=1) == 25
@test RBT.LiftPipe{Ctx{Int,(:x,),Tuple{Int}},Ctx{Int,(:x,:y),Tuple{Int,Int}},Int,Int}(
        RBT.LiftPipe{Int,Ctx{Int,(:x,),Tuple{Int}},Int,Int}(sqmap))(5, x=0, y=1) == 25
@test RBT.LiftPipe{Ctx{Int,(:x,),Tuple{Int}},Ctx{Temp{Int},(:x,:y),Tuple{Int,Int}},Int,Int}(
        RBT.LiftPipe{Int,Ctx{Int,(:x,),Tuple{Int}},Int,Int}(sqmap))(Temp{Int}(5), x=0, y=1) == 25
@test RBT.LiftPipe{Temp{Int},Ctx{Temp{Int},(:x,:y),Tuple{Int,Int}},Int,Int}(
        RBT.LiftPipe{Int,Temp{Int},Int,Int}(sqmap))(Temp{Int}(5), x=0, y=1) == 25

