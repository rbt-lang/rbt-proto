# Julia wrapper for header: /usr/include/expat.h
# Automatically generated using Clang.jl wrap_c, version 0.0.0


function XML_SetElementDeclHandler(parser::XML_Parser,eldecl::XML_ElementDeclHandler)
    ccall((:XML_SetElementDeclHandler,libexpat),Void,(XML_Parser,XML_ElementDeclHandler),parser,eldecl)
end

function XML_SetAttlistDeclHandler(parser::XML_Parser,attdecl::XML_AttlistDeclHandler)
    ccall((:XML_SetAttlistDeclHandler,libexpat),Void,(XML_Parser,XML_AttlistDeclHandler),parser,attdecl)
end

function XML_SetXmlDeclHandler(parser::XML_Parser,xmldecl::XML_XmlDeclHandler)
    ccall((:XML_SetXmlDeclHandler,libexpat),Void,(XML_Parser,XML_XmlDeclHandler),parser,xmldecl)
end

function XML_ParserCreate(encoding)
    ccall((:XML_ParserCreate,libexpat),XML_Parser,(Ptr{XML_Char},),encoding)
end

function XML_ParserCreateNS(encoding,namespaceSeparator::XML_Char)
    ccall((:XML_ParserCreateNS,libexpat),XML_Parser,(Ptr{XML_Char},XML_Char),encoding,namespaceSeparator)
end

function XML_ParserCreate_MM(encoding,memsuite,namespaceSeparator)
    ccall((:XML_ParserCreate_MM,libexpat),XML_Parser,(Ptr{XML_Char},Ptr{XML_Memory_Handling_Suite},Ptr{XML_Char}),encoding,memsuite,namespaceSeparator)
end

function XML_ParserReset(parser::XML_Parser,encoding)
    ccall((:XML_ParserReset,libexpat),XML_Bool,(XML_Parser,Ptr{XML_Char}),parser,encoding)
end

function XML_SetEntityDeclHandler(parser::XML_Parser,handler::XML_EntityDeclHandler)
    ccall((:XML_SetEntityDeclHandler,libexpat),Void,(XML_Parser,XML_EntityDeclHandler),parser,handler)
end

function XML_SetElementHandler(parser::XML_Parser,start::XML_StartElementHandler,_end::XML_EndElementHandler)
    ccall((:XML_SetElementHandler,libexpat),Void,(XML_Parser,XML_StartElementHandler,XML_EndElementHandler),parser,start,_end)
end

function XML_SetStartElementHandler(parser::XML_Parser,handler::XML_StartElementHandler)
    ccall((:XML_SetStartElementHandler,libexpat),Void,(XML_Parser,XML_StartElementHandler),parser,handler)
end

function XML_SetEndElementHandler(parser::XML_Parser,handler::XML_EndElementHandler)
    ccall((:XML_SetEndElementHandler,libexpat),Void,(XML_Parser,XML_EndElementHandler),parser,handler)
end

function XML_SetCharacterDataHandler(parser::XML_Parser,handler::XML_CharacterDataHandler)
    ccall((:XML_SetCharacterDataHandler,libexpat),Void,(XML_Parser,XML_CharacterDataHandler),parser,handler)
end

function XML_SetProcessingInstructionHandler(parser::XML_Parser,handler::XML_ProcessingInstructionHandler)
    ccall((:XML_SetProcessingInstructionHandler,libexpat),Void,(XML_Parser,XML_ProcessingInstructionHandler),parser,handler)
end

function XML_SetCommentHandler(parser::XML_Parser,handler::XML_CommentHandler)
    ccall((:XML_SetCommentHandler,libexpat),Void,(XML_Parser,XML_CommentHandler),parser,handler)
end

function XML_SetCdataSectionHandler(parser::XML_Parser,start::XML_StartCdataSectionHandler,_end::XML_EndCdataSectionHandler)
    ccall((:XML_SetCdataSectionHandler,libexpat),Void,(XML_Parser,XML_StartCdataSectionHandler,XML_EndCdataSectionHandler),parser,start,_end)
end

function XML_SetStartCdataSectionHandler(parser::XML_Parser,start::XML_StartCdataSectionHandler)
    ccall((:XML_SetStartCdataSectionHandler,libexpat),Void,(XML_Parser,XML_StartCdataSectionHandler),parser,start)
end

function XML_SetEndCdataSectionHandler(parser::XML_Parser,_end::XML_EndCdataSectionHandler)
    ccall((:XML_SetEndCdataSectionHandler,libexpat),Void,(XML_Parser,XML_EndCdataSectionHandler),parser,_end)
end

function XML_SetDefaultHandler(parser::XML_Parser,handler::XML_DefaultHandler)
    ccall((:XML_SetDefaultHandler,libexpat),Void,(XML_Parser,XML_DefaultHandler),parser,handler)
end

function XML_SetDefaultHandlerExpand(parser::XML_Parser,handler::XML_DefaultHandler)
    ccall((:XML_SetDefaultHandlerExpand,libexpat),Void,(XML_Parser,XML_DefaultHandler),parser,handler)
end

function XML_SetDoctypeDeclHandler(parser::XML_Parser,start::XML_StartDoctypeDeclHandler,_end::XML_EndDoctypeDeclHandler)
    ccall((:XML_SetDoctypeDeclHandler,libexpat),Void,(XML_Parser,XML_StartDoctypeDeclHandler,XML_EndDoctypeDeclHandler),parser,start,_end)
end

function XML_SetStartDoctypeDeclHandler(parser::XML_Parser,start::XML_StartDoctypeDeclHandler)
    ccall((:XML_SetStartDoctypeDeclHandler,libexpat),Void,(XML_Parser,XML_StartDoctypeDeclHandler),parser,start)
end

function XML_SetEndDoctypeDeclHandler(parser::XML_Parser,_end::XML_EndDoctypeDeclHandler)
    ccall((:XML_SetEndDoctypeDeclHandler,libexpat),Void,(XML_Parser,XML_EndDoctypeDeclHandler),parser,_end)
end

function XML_SetUnparsedEntityDeclHandler(parser::XML_Parser,handler::XML_UnparsedEntityDeclHandler)
    ccall((:XML_SetUnparsedEntityDeclHandler,libexpat),Void,(XML_Parser,XML_UnparsedEntityDeclHandler),parser,handler)
end

function XML_SetNotationDeclHandler(parser::XML_Parser,handler::XML_NotationDeclHandler)
    ccall((:XML_SetNotationDeclHandler,libexpat),Void,(XML_Parser,XML_NotationDeclHandler),parser,handler)
end

function XML_SetNamespaceDeclHandler(parser::XML_Parser,start::XML_StartNamespaceDeclHandler,_end::XML_EndNamespaceDeclHandler)
    ccall((:XML_SetNamespaceDeclHandler,libexpat),Void,(XML_Parser,XML_StartNamespaceDeclHandler,XML_EndNamespaceDeclHandler),parser,start,_end)
end

function XML_SetStartNamespaceDeclHandler(parser::XML_Parser,start::XML_StartNamespaceDeclHandler)
    ccall((:XML_SetStartNamespaceDeclHandler,libexpat),Void,(XML_Parser,XML_StartNamespaceDeclHandler),parser,start)
end

function XML_SetEndNamespaceDeclHandler(parser::XML_Parser,_end::XML_EndNamespaceDeclHandler)
    ccall((:XML_SetEndNamespaceDeclHandler,libexpat),Void,(XML_Parser,XML_EndNamespaceDeclHandler),parser,_end)
end

function XML_SetNotStandaloneHandler(parser::XML_Parser,handler::XML_NotStandaloneHandler)
    ccall((:XML_SetNotStandaloneHandler,libexpat),Void,(XML_Parser,XML_NotStandaloneHandler),parser,handler)
end

function XML_SetExternalEntityRefHandler(parser::XML_Parser,handler::XML_ExternalEntityRefHandler)
    ccall((:XML_SetExternalEntityRefHandler,libexpat),Void,(XML_Parser,XML_ExternalEntityRefHandler),parser,handler)
end

function XML_SetExternalEntityRefHandlerArg(parser::XML_Parser,arg)
    ccall((:XML_SetExternalEntityRefHandlerArg,libexpat),Void,(XML_Parser,Ptr{Void}),parser,arg)
end

function XML_SetSkippedEntityHandler(parser::XML_Parser,handler::XML_SkippedEntityHandler)
    ccall((:XML_SetSkippedEntityHandler,libexpat),Void,(XML_Parser,XML_SkippedEntityHandler),parser,handler)
end

function XML_SetUnknownEncodingHandler(parser::XML_Parser,handler::XML_UnknownEncodingHandler,encodingHandlerData)
    ccall((:XML_SetUnknownEncodingHandler,libexpat),Void,(XML_Parser,XML_UnknownEncodingHandler,Ptr{Void}),parser,handler,encodingHandlerData)
end

function XML_DefaultCurrent(parser::XML_Parser)
    ccall((:XML_DefaultCurrent,libexpat),Void,(XML_Parser,),parser)
end

function XML_SetReturnNSTriplet(parser::XML_Parser,do_nst::Cint)
    ccall((:XML_SetReturnNSTriplet,libexpat),Void,(XML_Parser,Cint),parser,do_nst)
end

function XML_SetUserData(parser::XML_Parser,userData)
    ccall((:XML_SetUserData,libexpat),Void,(XML_Parser,Ptr{Void}),parser,userData)
end

function XML_SetEncoding(parser::XML_Parser,encoding)
    ccall((:XML_SetEncoding,libexpat),Cint,(XML_Parser,Ptr{XML_Char}),parser,encoding)
end

function XML_UseParserAsHandlerArg(parser::XML_Parser)
    ccall((:XML_UseParserAsHandlerArg,libexpat),Void,(XML_Parser,),parser)
end

function XML_UseForeignDTD(parser::XML_Parser,useDTD::XML_Bool)
    ccall((:XML_UseForeignDTD,libexpat),Cint,(XML_Parser,XML_Bool),parser,useDTD)
end

function XML_SetBase(parser::XML_Parser,base)
    ccall((:XML_SetBase,libexpat),Cint,(XML_Parser,Ptr{XML_Char}),parser,base)
end

function XML_GetBase(parser::XML_Parser)
    ccall((:XML_GetBase,libexpat),Ptr{XML_Char},(XML_Parser,),parser)
end

function XML_GetSpecifiedAttributeCount(parser::XML_Parser)
    ccall((:XML_GetSpecifiedAttributeCount,libexpat),Cint,(XML_Parser,),parser)
end

function XML_GetIdAttributeIndex(parser::XML_Parser)
    ccall((:XML_GetIdAttributeIndex,libexpat),Cint,(XML_Parser,),parser)
end

function XML_Parse(parser::XML_Parser,s,len::Cint,isFinal::Cint)
    ccall((:XML_Parse,libexpat),Cint,(XML_Parser,Cstring,Cint,Cint),parser,s,len,isFinal)
end

function XML_GetBuffer(parser::XML_Parser,len::Cint)
    ccall((:XML_GetBuffer,libexpat),Ptr{Void},(XML_Parser,Cint),parser,len)
end

function XML_ParseBuffer(parser::XML_Parser,len::Cint,isFinal::Cint)
    ccall((:XML_ParseBuffer,libexpat),Cint,(XML_Parser,Cint,Cint),parser,len,isFinal)
end

function XML_StopParser(parser::XML_Parser,resumable::XML_Bool)
    ccall((:XML_StopParser,libexpat),Cint,(XML_Parser,XML_Bool),parser,resumable)
end

function XML_ResumeParser(parser::XML_Parser)
    ccall((:XML_ResumeParser,libexpat),Cint,(XML_Parser,),parser)
end

function XML_GetParsingStatus(parser::XML_Parser,status)
    ccall((:XML_GetParsingStatus,libexpat),Void,(XML_Parser,Ptr{XML_ParsingStatus}),parser,status)
end

function XML_ExternalEntityParserCreate(parser::XML_Parser,context,encoding)
    ccall((:XML_ExternalEntityParserCreate,libexpat),XML_Parser,(XML_Parser,Ptr{XML_Char},Ptr{XML_Char}),parser,context,encoding)
end

function XML_SetParamEntityParsing(parser::XML_Parser,parsing::XML_ParamEntityParsing)
    ccall((:XML_SetParamEntityParsing,libexpat),Cint,(XML_Parser,XML_ParamEntityParsing),parser,parsing)
end

function XML_SetHashSalt(parser::XML_Parser,hash_salt::Culong)
    ccall((:XML_SetHashSalt,libexpat),Cint,(XML_Parser,Culong),parser,hash_salt)
end

function XML_GetErrorCode(parser::XML_Parser)
    ccall((:XML_GetErrorCode,libexpat),Cint,(XML_Parser,),parser)
end

function XML_GetCurrentLineNumber(parser::XML_Parser)
    ccall((:XML_GetCurrentLineNumber,libexpat),XML_Size,(XML_Parser,),parser)
end

function XML_GetCurrentColumnNumber(parser::XML_Parser)
    ccall((:XML_GetCurrentColumnNumber,libexpat),XML_Size,(XML_Parser,),parser)
end

function XML_GetCurrentByteIndex(parser::XML_Parser)
    ccall((:XML_GetCurrentByteIndex,libexpat),XML_Index,(XML_Parser,),parser)
end

function XML_GetCurrentByteCount(parser::XML_Parser)
    ccall((:XML_GetCurrentByteCount,libexpat),Cint,(XML_Parser,),parser)
end

function XML_GetInputContext(parser::XML_Parser,offset,size)
    ccall((:XML_GetInputContext,libexpat),Cstring,(XML_Parser,Ptr{Cint},Ptr{Cint}),parser,offset,size)
end

function XML_FreeContentModel(parser::XML_Parser,model)
    ccall((:XML_FreeContentModel,libexpat),Void,(XML_Parser,Ptr{XML_Content}),parser,model)
end

function XML_MemMalloc(parser::XML_Parser,size::Cint)
    ccall((:XML_MemMalloc,libexpat),Ptr{Void},(XML_Parser,Cint),parser,size)
end

function XML_MemRealloc(parser::XML_Parser,ptr,size::Cint)
    ccall((:XML_MemRealloc,libexpat),Ptr{Void},(XML_Parser,Ptr{Void},Cint),parser,ptr,size)
end

function XML_MemFree(parser::XML_Parser,ptr)
    ccall((:XML_MemFree,libexpat),Void,(XML_Parser,Ptr{Void}),parser,ptr)
end

function XML_ParserFree(parser::XML_Parser)
    ccall((:XML_ParserFree,libexpat),Void,(XML_Parser,),parser)
end

function XML_ErrorString(code::XML_Error)
    ccall((:XML_ErrorString,libexpat),Ptr{XML_LChar},(XML_Error,),code)
end

function XML_ExpatVersion()
    ccall((:XML_ExpatVersion,libexpat),Ptr{XML_LChar},())
end

function XML_ExpatVersionInfo()
    ccall((:XML_ExpatVersionInfo,libexpat),XML_Expat_Version,())
end

function XML_GetFeatureList()
    ccall((:XML_GetFeatureList,libexpat),Ptr{XML_Feature},())
end
