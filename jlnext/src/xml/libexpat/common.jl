# Automatically generated using Clang.jl wrap_c, version 0.0.0

using Compat

const Expat_INCLUDED = 1
const Expat_External_INCLUDED = 1

# Skipping MacroDefinition: XMLPARSEAPI ( type ) XMLIMPORT type XMLCALL
# Skipping MacroDefinition: XML_TRUE ( ( XML_Bool ) 1 )
# Skipping MacroDefinition: XML_FALSE ( ( XML_Bool ) 0 )

# begin enum XML_Status
typealias XML_Status UInt32
const XML_STATUS_ERROR = (UInt32)(0)
const XML_STATUS_OK = (UInt32)(1)
const XML_STATUS_SUSPENDED = (UInt32)(2)
# end enum XML_Status

# Skipping MacroDefinition: XML_GetUserData ( parser ) ( * ( void * * ) ( parser ) )

#=
const XML_GetErrorLineNumber = XML_GetCurrentLineNumber
const XML_GetErrorColumnNumber = XML_GetCurrentColumnNumber
const XML_GetErrorByteIndex = XML_GetCurrentByteIndex
=#
const XML_MAJOR_VERSION = 2
const XML_MINOR_VERSION = 1
const XML_MICRO_VERSION = 0

typealias XML_Char UInt8
typealias XML_LChar UInt8
typealias XML_Index Clong
typealias XML_Size Culong

type XML_ParserStruct
end

typealias XML_Parser Ptr{XML_ParserStruct}
typealias XML_Bool Cuchar

# begin enum XML_Error
typealias XML_Error UInt32
const XML_ERROR_NONE = (UInt32)(0)
const XML_ERROR_NO_MEMORY = (UInt32)(1)
const XML_ERROR_SYNTAX = (UInt32)(2)
const XML_ERROR_NO_ELEMENTS = (UInt32)(3)
const XML_ERROR_INVALID_TOKEN = (UInt32)(4)
const XML_ERROR_UNCLOSED_TOKEN = (UInt32)(5)
const XML_ERROR_PARTIAL_CHAR = (UInt32)(6)
const XML_ERROR_TAG_MISMATCH = (UInt32)(7)
const XML_ERROR_DUPLICATE_ATTRIBUTE = (UInt32)(8)
const XML_ERROR_JUNK_AFTER_DOC_ELEMENT = (UInt32)(9)
const XML_ERROR_PARAM_ENTITY_REF = (UInt32)(10)
const XML_ERROR_UNDEFINED_ENTITY = (UInt32)(11)
const XML_ERROR_RECURSIVE_ENTITY_REF = (UInt32)(12)
const XML_ERROR_ASYNC_ENTITY = (UInt32)(13)
const XML_ERROR_BAD_CHAR_REF = (UInt32)(14)
const XML_ERROR_BINARY_ENTITY_REF = (UInt32)(15)
const XML_ERROR_ATTRIBUTE_EXTERNAL_ENTITY_REF = (UInt32)(16)
const XML_ERROR_MISPLACED_XML_PI = (UInt32)(17)
const XML_ERROR_UNKNOWN_ENCODING = (UInt32)(18)
const XML_ERROR_INCORRECT_ENCODING = (UInt32)(19)
const XML_ERROR_UNCLOSED_CDATA_SECTION = (UInt32)(20)
const XML_ERROR_EXTERNAL_ENTITY_HANDLING = (UInt32)(21)
const XML_ERROR_NOT_STANDALONE = (UInt32)(22)
const XML_ERROR_UNEXPECTED_STATE = (UInt32)(23)
const XML_ERROR_ENTITY_DECLARED_IN_PE = (UInt32)(24)
const XML_ERROR_FEATURE_REQUIRES_XML_DTD = (UInt32)(25)
const XML_ERROR_CANT_CHANGE_FEATURE_ONCE_PARSING = (UInt32)(26)
const XML_ERROR_UNBOUND_PREFIX = (UInt32)(27)
const XML_ERROR_UNDECLARING_PREFIX = (UInt32)(28)
const XML_ERROR_INCOMPLETE_PE = (UInt32)(29)
const XML_ERROR_XML_DECL = (UInt32)(30)
const XML_ERROR_TEXT_DECL = (UInt32)(31)
const XML_ERROR_PUBLICID = (UInt32)(32)
const XML_ERROR_SUSPENDED = (UInt32)(33)
const XML_ERROR_NOT_SUSPENDED = (UInt32)(34)
const XML_ERROR_ABORTED = (UInt32)(35)
const XML_ERROR_FINISHED = (UInt32)(36)
const XML_ERROR_SUSPEND_PE = (UInt32)(37)
const XML_ERROR_RESERVED_PREFIX_XML = (UInt32)(38)
const XML_ERROR_RESERVED_PREFIX_XMLNS = (UInt32)(39)
const XML_ERROR_RESERVED_NAMESPACE_URI = (UInt32)(40)
# end enum XML_Error

# begin enum XML_Content_Type
typealias XML_Content_Type UInt32
const XML_CTYPE_EMPTY = (UInt32)(1)
const XML_CTYPE_ANY = (UInt32)(2)
const XML_CTYPE_MIXED = (UInt32)(3)
const XML_CTYPE_NAME = (UInt32)(4)
const XML_CTYPE_CHOICE = (UInt32)(5)
const XML_CTYPE_SEQ = (UInt32)(6)
# end enum XML_Content_Type

# begin enum XML_Content_Quant
typealias XML_Content_Quant UInt32
const XML_CQUANT_NONE = (UInt32)(0)
const XML_CQUANT_OPT = (UInt32)(1)
const XML_CQUANT_REP = (UInt32)(2)
const XML_CQUANT_PLUS = (UInt32)(3)
# end enum XML_Content_Quant

#=
typealias XML_Content XML_cp
=#

type XML_cp
    _type::XML_Content_Type
    quant::XML_Content_Quant
    name::Ptr{XML_Char}
    numchildren::UInt32
    children::Ptr{XML_cp}
end

typealias XML_ElementDeclHandler Ptr{Void}
typealias XML_AttlistDeclHandler Ptr{Void}
typealias XML_XmlDeclHandler Ptr{Void}

type XML_Memory_Handling_Suite
    malloc_fcn::Ptr{Void}
    realloc_fcn::Ptr{Void}
    free_fcn::Ptr{Void}
end

typealias XML_StartElementHandler Ptr{Void}
typealias XML_EndElementHandler Ptr{Void}
typealias XML_CharacterDataHandler Ptr{Void}
typealias XML_ProcessingInstructionHandler Ptr{Void}
typealias XML_CommentHandler Ptr{Void}
typealias XML_StartCdataSectionHandler Ptr{Void}
typealias XML_EndCdataSectionHandler Ptr{Void}
typealias XML_DefaultHandler Ptr{Void}
typealias XML_StartDoctypeDeclHandler Ptr{Void}
typealias XML_EndDoctypeDeclHandler Ptr{Void}
typealias XML_EntityDeclHandler Ptr{Void}
typealias XML_UnparsedEntityDeclHandler Ptr{Void}
typealias XML_NotationDeclHandler Ptr{Void}
typealias XML_StartNamespaceDeclHandler Ptr{Void}
typealias XML_EndNamespaceDeclHandler Ptr{Void}
typealias XML_NotStandaloneHandler Ptr{Void}
typealias XML_ExternalEntityRefHandler Ptr{Void}
typealias XML_SkippedEntityHandler Ptr{Void}

type XML_Encoding
    map::NTuple{256,Cint}
    data::Ptr{Void}
    convert::Ptr{Void}
    release::Ptr{Void}
end

typealias XML_UnknownEncodingHandler Ptr{Void}

# begin enum XML_Parsing
typealias XML_Parsing UInt32
const XML_INITIALIZED = (UInt32)(0)
const XML_PARSING = (UInt32)(1)
const XML_FINISHED = (UInt32)(2)
const XML_SUSPENDED = (UInt32)(3)
# end enum XML_Parsing

type XML_ParsingStatus
    parsing::XML_Parsing
    finalBuffer::XML_Bool
end

# begin enum XML_ParamEntityParsing
typealias XML_ParamEntityParsing UInt32
const XML_PARAM_ENTITY_PARSING_NEVER = (UInt32)(0)
const XML_PARAM_ENTITY_PARSING_UNLESS_STANDALONE = (UInt32)(1)
const XML_PARAM_ENTITY_PARSING_ALWAYS = (UInt32)(2)
# end enum XML_ParamEntityParsing

type XML_Expat_Version
    major::Cint
    minor::Cint
    micro::Cint
end

# begin enum XML_FeatureEnum
typealias XML_FeatureEnum UInt32
const XML_FEATURE_END = (UInt32)(0)
const XML_FEATURE_UNICODE = (UInt32)(1)
const XML_FEATURE_UNICODE_WCHAR_T = (UInt32)(2)
const XML_FEATURE_DTD = (UInt32)(3)
const XML_FEATURE_CONTEXT_BYTES = (UInt32)(4)
const XML_FEATURE_MIN_SIZE = (UInt32)(5)
const XML_FEATURE_SIZEOF_XML_CHAR = (UInt32)(6)
const XML_FEATURE_SIZEOF_XML_LCHAR = (UInt32)(7)
const XML_FEATURE_NS = (UInt32)(8)
const XML_FEATURE_LARGE_SIZE = (UInt32)(9)
const XML_FEATURE_ATTR_INFO = (UInt32)(10)
# end enum XML_FeatureEnum

type XML_Feature
    feature::XML_FeatureEnum
    name::Ptr{XML_LChar}
    value::Clong
end
