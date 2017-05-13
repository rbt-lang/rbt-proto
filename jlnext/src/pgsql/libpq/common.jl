# Automatically generated using Clang.jl wrap_c, version 0.0.0

using Compat

# Skipping MacroDefinition: InvalidOid ( ( Oid ) 0 )

const OID_MAX = UINT_MAX
const PG_DIAG_SEVERITY = 'S'
const PG_DIAG_SQLSTATE = 'C'
const PG_DIAG_MESSAGE_PRIMARY = 'M'
const PG_DIAG_MESSAGE_DETAIL = 'D'
const PG_DIAG_MESSAGE_HINT = 'H'
const PG_DIAG_STATEMENT_POSITION = 'P'
const PG_DIAG_INTERNAL_POSITION = 'p'
const PG_DIAG_INTERNAL_QUERY = 'q'
const PG_DIAG_CONTEXT = 'W'
const PG_DIAG_SCHEMA_NAME = 's'
const PG_DIAG_TABLE_NAME = 't'
const PG_DIAG_COLUMN_NAME = 'c'
const PG_DIAG_DATATYPE_NAME = 'd'
const PG_DIAG_CONSTRAINT_NAME = 'n'
const PG_DIAG_SOURCE_FILE = 'F'
const PG_DIAG_SOURCE_LINE = 'L'
const PG_DIAG_SOURCE_FUNCTION = 'R'
const PG_COPYRES_ATTRS = 0x01
const PG_COPYRES_TUPLES = 0x02
const PG_COPYRES_EVENTS = 0x04
const PG_COPYRES_NOTICEHOOKS = 0x08

# Skipping MacroDefinition: PQsetdb ( M_PGHOST , M_PGPORT , M_PGOPT , M_PGTTY , M_DBNAME ) PQsetdbLogin ( M_PGHOST , M_PGPORT , M_PGOPT , M_PGTTY , M_DBNAME , NULL , NULL )
# Skipping MacroDefinition: PQfreeNotify ( ptr ) PQfreemem ( ptr )

const PQnoPasswordSupplied = "fe_sendauth: no password supplied\n"

typealias Oid UInt32
typealias pg_int64 Clong

# begin enum ANONYMOUS_1
typealias ANONYMOUS_1 UInt32
const CONNECTION_OK = (UInt32)(0)
const CONNECTION_BAD = (UInt32)(1)
const CONNECTION_STARTED = (UInt32)(2)
const CONNECTION_MADE = (UInt32)(3)
const CONNECTION_AWAITING_RESPONSE = (UInt32)(4)
const CONNECTION_AUTH_OK = (UInt32)(5)
const CONNECTION_SETENV = (UInt32)(6)
const CONNECTION_SSL_STARTUP = (UInt32)(7)
const CONNECTION_NEEDED = (UInt32)(8)
# end enum ANONYMOUS_1

# begin enum ConnStatusType
typealias ConnStatusType UInt32
const CONNECTION_OK = (UInt32)(0)
const CONNECTION_BAD = (UInt32)(1)
const CONNECTION_STARTED = (UInt32)(2)
const CONNECTION_MADE = (UInt32)(3)
const CONNECTION_AWAITING_RESPONSE = (UInt32)(4)
const CONNECTION_AUTH_OK = (UInt32)(5)
const CONNECTION_SETENV = (UInt32)(6)
const CONNECTION_SSL_STARTUP = (UInt32)(7)
const CONNECTION_NEEDED = (UInt32)(8)
# end enum ConnStatusType

# begin enum ANONYMOUS_2
typealias ANONYMOUS_2 UInt32
const PGRES_POLLING_FAILED = (UInt32)(0)
const PGRES_POLLING_READING = (UInt32)(1)
const PGRES_POLLING_WRITING = (UInt32)(2)
const PGRES_POLLING_OK = (UInt32)(3)
const PGRES_POLLING_ACTIVE = (UInt32)(4)
# end enum ANONYMOUS_2

# begin enum PostgresPollingStatusType
typealias PostgresPollingStatusType UInt32
const PGRES_POLLING_FAILED = (UInt32)(0)
const PGRES_POLLING_READING = (UInt32)(1)
const PGRES_POLLING_WRITING = (UInt32)(2)
const PGRES_POLLING_OK = (UInt32)(3)
const PGRES_POLLING_ACTIVE = (UInt32)(4)
# end enum PostgresPollingStatusType

# begin enum ANONYMOUS_3
typealias ANONYMOUS_3 UInt32
const PGRES_EMPTY_QUERY = (UInt32)(0)
const PGRES_COMMAND_OK = (UInt32)(1)
const PGRES_TUPLES_OK = (UInt32)(2)
const PGRES_COPY_OUT = (UInt32)(3)
const PGRES_COPY_IN = (UInt32)(4)
const PGRES_BAD_RESPONSE = (UInt32)(5)
const PGRES_NONFATAL_ERROR = (UInt32)(6)
const PGRES_FATAL_ERROR = (UInt32)(7)
const PGRES_COPY_BOTH = (UInt32)(8)
const PGRES_SINGLE_TUPLE = (UInt32)(9)
# end enum ANONYMOUS_3

# begin enum ExecStatusType
typealias ExecStatusType UInt32
const PGRES_EMPTY_QUERY = (UInt32)(0)
const PGRES_COMMAND_OK = (UInt32)(1)
const PGRES_TUPLES_OK = (UInt32)(2)
const PGRES_COPY_OUT = (UInt32)(3)
const PGRES_COPY_IN = (UInt32)(4)
const PGRES_BAD_RESPONSE = (UInt32)(5)
const PGRES_NONFATAL_ERROR = (UInt32)(6)
const PGRES_FATAL_ERROR = (UInt32)(7)
const PGRES_COPY_BOTH = (UInt32)(8)
const PGRES_SINGLE_TUPLE = (UInt32)(9)
# end enum ExecStatusType

# begin enum ANONYMOUS_4
typealias ANONYMOUS_4 UInt32
const PQTRANS_IDLE = (UInt32)(0)
const PQTRANS_ACTIVE = (UInt32)(1)
const PQTRANS_INTRANS = (UInt32)(2)
const PQTRANS_INERROR = (UInt32)(3)
const PQTRANS_UNKNOWN = (UInt32)(4)
# end enum ANONYMOUS_4

# begin enum PGTransactionStatusType
typealias PGTransactionStatusType UInt32
const PQTRANS_IDLE = (UInt32)(0)
const PQTRANS_ACTIVE = (UInt32)(1)
const PQTRANS_INTRANS = (UInt32)(2)
const PQTRANS_INERROR = (UInt32)(3)
const PQTRANS_UNKNOWN = (UInt32)(4)
# end enum PGTransactionStatusType

# begin enum ANONYMOUS_5
typealias ANONYMOUS_5 UInt32
const PQERRORS_TERSE = (UInt32)(0)
const PQERRORS_DEFAULT = (UInt32)(1)
const PQERRORS_VERBOSE = (UInt32)(2)
# end enum ANONYMOUS_5

# begin enum PGVerbosity
typealias PGVerbosity UInt32
const PQERRORS_TERSE = (UInt32)(0)
const PQERRORS_DEFAULT = (UInt32)(1)
const PQERRORS_VERBOSE = (UInt32)(2)
# end enum PGVerbosity

# begin enum ANONYMOUS_6
typealias ANONYMOUS_6 UInt32
const PQPING_OK = (UInt32)(0)
const PQPING_REJECT = (UInt32)(1)
const PQPING_NO_RESPONSE = (UInt32)(2)
const PQPING_NO_ATTEMPT = (UInt32)(3)
# end enum ANONYMOUS_6

# begin enum PGPing
typealias PGPing UInt32
const PQPING_OK = (UInt32)(0)
const PQPING_REJECT = (UInt32)(1)
const PQPING_NO_RESPONSE = (UInt32)(2)
const PQPING_NO_ATTEMPT = (UInt32)(3)
# end enum PGPing

type pg_conn
end

typealias PGconn Void

type pg_result
end

typealias PGresult Void

type pg_cancel
end

typealias PGcancel Void

type pgNotify
    relname::Cstring
    be_pid::Cint
    extra::Cstring
    next::Ptr{pgNotify}
end

type PGnotify
    relname::Cstring
    be_pid::Cint
    extra::Cstring
    next::Ptr{pgNotify}
end

typealias PQnoticeReceiver Ptr{Void}
typealias PQnoticeProcessor Ptr{Void}
typealias pqbool UInt8

type _PQprintOpt
    header::pqbool
    align::pqbool
    standard::pqbool
    html3::pqbool
    expanded::pqbool
    pager::pqbool
    fieldSep::Cstring
    tableOpt::Cstring
    caption::Cstring
    fieldName::Ptr{Cstring}
end

type PQprintOpt
    header::pqbool
    align::pqbool
    standard::pqbool
    html3::pqbool
    expanded::pqbool
    pager::pqbool
    fieldSep::Cstring
    tableOpt::Cstring
    caption::Cstring
    fieldName::Ptr{Cstring}
end

type _PQconninfoOption
    keyword::Cstring
    envvar::Cstring
    compiled::Cstring
    val::Cstring
    label::Cstring
    dispchar::Cstring
    dispsize::Cint
end

type PQconninfoOption
    keyword::Cstring
    envvar::Cstring
    compiled::Cstring
    val::Cstring
    label::Cstring
    dispchar::Cstring
    dispsize::Cint
end

type PQArgBlock
    len::Cint
    isint::Cint
    u::Void
end

type pgresAttDesc
    name::Cstring
    tableid::Oid
    columnid::Cint
    format::Cint
    typid::Oid
    typlen::Cint
    atttypmod::Cint
end

type PGresAttDesc
    name::Cstring
    tableid::Oid
    columnid::Cint
    format::Cint
    typid::Oid
    typlen::Cint
    atttypmod::Cint
end

typealias pgthreadlock_t Ptr{Void}
