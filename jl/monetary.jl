
immutable Monetary{C}
    val::Int64

    Monetary(minor::Integer) = new(minor)
    Monetary(major::Integer, minor::Integer) = new(major*10^scale(Monetary{C})+minor)
end

@generated show(io::IO, m::Monetary) =
    let s = scale(m)
        if s == 0
            quote
                print(io, m.val)
            end
        else
            fmt = "%.0$(s)f"
            f = 10^s
            quote
                @printf(io, $fmt, m.val/$f)
            end
        end
    end

currency{C}(::Union{Type{Monetary{C}},Monetary{C}}) = C
scale{C}(::Type{Monetary{C}}) = 2
scale(m::Monetary) = scale(typeof(m))

dollars(m::Monetary) = div(m.val, 10^scale(m))
cents(m::Monetary) = rem(m.val, 10^scale(m))

Base.zero{M<:Monetary}(::Union{Type{M},M}) = M(0)
Base.one{M<:Monetary}(::Union{Type{M},M}) = M(1, 0)

Base.isfinite{M<:Monetary}(::Union{Type{M},M}) = true
Base.eps{M<:Monetary}(::M) = M(1)
Base.typemax{M<:Monetary}(::Union{Type{M},M}) = M(typemax(Int64))
Base.typemin{M<:Monetary}(::Union{Type{M},M}) = M(typemin(Int64))
Base.isless{M<:Monetary}(x::M, y::M) = isless(x.val, y.val)
(==){M<:Monetary}(x::M, y::M) = x.val == y.val

Base.round{M<:Monetary}(::Type{M}, x::AbstractFloat) =
    M(round(Int64, x*10^scale(M)))
Base.round{M<:Monetary}(::Type{M}, x::AbstractFloat, r::RoundingMode) =
    M(round(Int64, x*10^scale(M), r))

Base.convert{M<:Monetary}(::Type{M}, x::Integer) = M(x, 0)
Base.convert{M<:Monetary}(::Type{M}, x::Real) = M(round(Int64, x*10^scale(M)))
Base.convert{T<:Number}(::Type{T}, x::Monetary) = convert(T, x.val/10^scale(x))

(+){M<:Monetary}(m::M) = m
(-){M<:Monetary}(m::M) = M(-m.val)

(+){M<:Monetary}(m1::M, m2::M) = M(m1.val+m2.val)
(-){M<:Monetary}(m1::M, m2::M) = M(m1.val-m2.val)

(*){M<:Monetary}(m::M, k::Integer) = M(k*m.val)
(*){M<:Monetary}(m::M, k::Real) = M(round(Int64, k*m.val))
(*)(k::Number, m::Monetary) = m*k
(/)(m::Monetary, k::Number) = (one(k)/k)*m
(/){M<:Monetary}(m1::M, m2::M) = m1.val/m2.val

const USD = convert(Monetary{:USD}, 1)
const CAD = convert(Monetary{:CAD}, 1)
const GBR = convert(Monetary{:GBR}, 1)
const EUR = convert(Monetary{:EUR}, 1)

