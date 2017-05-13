# Julia wrapper for header: /usr/include/postgresql/libpq-fe.h
# Automatically generated using Clang.jl wrap_c, version 0.0.0


function PQconnectStart(conninfo)
    ccall((:PQconnectStart,libpq),Ptr{PGconn},(Cstring,),conninfo)
end

function PQconnectStartParams(keywords,values,expand_dbname::Cint)
    ccall((:PQconnectStartParams,libpq),Ptr{PGconn},(Ptr{Cstring},Ptr{Cstring},Cint),keywords,values,expand_dbname)
end

function PQconnectPoll(conn)
    ccall((:PQconnectPoll,libpq),PostgresPollingStatusType,(Ptr{PGconn},),conn)
end

function PQconnectdb(conninfo)
    ccall((:PQconnectdb,libpq),Ptr{PGconn},(Cstring,),conninfo)
end

function PQconnectdbParams(keywords,values,expand_dbname::Cint)
    ccall((:PQconnectdbParams,libpq),Ptr{PGconn},(Ptr{Cstring},Ptr{Cstring},Cint),keywords,values,expand_dbname)
end

function PQsetdbLogin(pghost,pgport,pgoptions,pgtty,dbName,login,pwd)
    ccall((:PQsetdbLogin,libpq),Ptr{PGconn},(Cstring,Cstring,Cstring,Cstring,Cstring,Cstring,Cstring),pghost,pgport,pgoptions,pgtty,dbName,login,pwd)
end

function PQfinish(conn)
    ccall((:PQfinish,libpq),Void,(Ptr{PGconn},),conn)
end

function PQconndefaults()
    ccall((:PQconndefaults,libpq),Ptr{PQconninfoOption},())
end

function PQconninfoParse(conninfo,errmsg)
    ccall((:PQconninfoParse,libpq),Ptr{PQconninfoOption},(Cstring,Ptr{Cstring}),conninfo,errmsg)
end

function PQconninfo(conn)
    ccall((:PQconninfo,libpq),Ptr{PQconninfoOption},(Ptr{PGconn},),conn)
end

function PQconninfoFree(connOptions)
    ccall((:PQconninfoFree,libpq),Void,(Ptr{PQconninfoOption},),connOptions)
end

function PQresetStart(conn)
    ccall((:PQresetStart,libpq),Cint,(Ptr{PGconn},),conn)
end

function PQresetPoll(conn)
    ccall((:PQresetPoll,libpq),PostgresPollingStatusType,(Ptr{PGconn},),conn)
end

function PQreset(conn)
    ccall((:PQreset,libpq),Void,(Ptr{PGconn},),conn)
end

function PQgetCancel(conn)
    ccall((:PQgetCancel,libpq),Ptr{PGcancel},(Ptr{PGconn},),conn)
end

function PQfreeCancel(cancel)
    ccall((:PQfreeCancel,libpq),Void,(Ptr{PGcancel},),cancel)
end

function PQcancel(cancel,errbuf,errbufsize::Cint)
    ccall((:PQcancel,libpq),Cint,(Ptr{PGcancel},Cstring,Cint),cancel,errbuf,errbufsize)
end

function PQrequestCancel(conn)
    ccall((:PQrequestCancel,libpq),Cint,(Ptr{PGconn},),conn)
end

function PQdb(conn)
    ccall((:PQdb,libpq),Cstring,(Ptr{PGconn},),conn)
end

function PQuser(conn)
    ccall((:PQuser,libpq),Cstring,(Ptr{PGconn},),conn)
end

function PQpass(conn)
    ccall((:PQpass,libpq),Cstring,(Ptr{PGconn},),conn)
end

function PQhost(conn)
    ccall((:PQhost,libpq),Cstring,(Ptr{PGconn},),conn)
end

function PQport(conn)
    ccall((:PQport,libpq),Cstring,(Ptr{PGconn},),conn)
end

function PQtty(conn)
    ccall((:PQtty,libpq),Cstring,(Ptr{PGconn},),conn)
end

function PQoptions(conn)
    ccall((:PQoptions,libpq),Cstring,(Ptr{PGconn},),conn)
end

function PQstatus(conn)
    ccall((:PQstatus,libpq),ConnStatusType,(Ptr{PGconn},),conn)
end

function PQtransactionStatus(conn)
    ccall((:PQtransactionStatus,libpq),PGTransactionStatusType,(Ptr{PGconn},),conn)
end

function PQparameterStatus(conn,paramName)
    ccall((:PQparameterStatus,libpq),Cstring,(Ptr{PGconn},Cstring),conn,paramName)
end

function PQprotocolVersion(conn)
    ccall((:PQprotocolVersion,libpq),Cint,(Ptr{PGconn},),conn)
end

function PQserverVersion(conn)
    ccall((:PQserverVersion,libpq),Cint,(Ptr{PGconn},),conn)
end

function PQerrorMessage(conn)
    ccall((:PQerrorMessage,libpq),Cstring,(Ptr{PGconn},),conn)
end

function PQsocket(conn)
    ccall((:PQsocket,libpq),Cint,(Ptr{PGconn},),conn)
end

function PQbackendPID(conn)
    ccall((:PQbackendPID,libpq),Cint,(Ptr{PGconn},),conn)
end

function PQconnectionNeedsPassword(conn)
    ccall((:PQconnectionNeedsPassword,libpq),Cint,(Ptr{PGconn},),conn)
end

function PQconnectionUsedPassword(conn)
    ccall((:PQconnectionUsedPassword,libpq),Cint,(Ptr{PGconn},),conn)
end

function PQclientEncoding(conn)
    ccall((:PQclientEncoding,libpq),Cint,(Ptr{PGconn},),conn)
end

function PQsetClientEncoding(conn,encoding)
    ccall((:PQsetClientEncoding,libpq),Cint,(Ptr{PGconn},Cstring),conn,encoding)
end

function PQsslInUse(conn)
    ccall((:PQsslInUse,libpq),Cint,(Ptr{PGconn},),conn)
end

function PQsslStruct(conn,struct_name)
    ccall((:PQsslStruct,libpq),Ptr{Void},(Ptr{PGconn},Cstring),conn,struct_name)
end

function PQsslAttribute(conn,attribute_name)
    ccall((:PQsslAttribute,libpq),Cstring,(Ptr{PGconn},Cstring),conn,attribute_name)
end

function PQsslAttributeNames(conn)
    ccall((:PQsslAttributeNames,libpq),Ptr{Cstring},(Ptr{PGconn},),conn)
end

function PQgetssl(conn)
    ccall((:PQgetssl,libpq),Ptr{Void},(Ptr{PGconn},),conn)
end

function PQinitSSL(do_init::Cint)
    ccall((:PQinitSSL,libpq),Void,(Cint,),do_init)
end

function PQinitOpenSSL(do_ssl::Cint,do_crypto::Cint)
    ccall((:PQinitOpenSSL,libpq),Void,(Cint,Cint),do_ssl,do_crypto)
end

function PQsetErrorVerbosity(conn,verbosity::PGVerbosity)
    ccall((:PQsetErrorVerbosity,libpq),PGVerbosity,(Ptr{PGconn},PGVerbosity),conn,verbosity)
end

function PQtrace(conn,debug_port)
    ccall((:PQtrace,libpq),Void,(Ptr{PGconn},Ptr{FILE}),conn,debug_port)
end

function PQuntrace(conn)
    ccall((:PQuntrace,libpq),Void,(Ptr{PGconn},),conn)
end

function PQsetNoticeReceiver(conn,proc::PQnoticeReceiver,arg)
    ccall((:PQsetNoticeReceiver,libpq),PQnoticeReceiver,(Ptr{PGconn},PQnoticeReceiver,Ptr{Void}),conn,proc,arg)
end

function PQsetNoticeProcessor(conn,proc::PQnoticeProcessor,arg)
    ccall((:PQsetNoticeProcessor,libpq),PQnoticeProcessor,(Ptr{PGconn},PQnoticeProcessor,Ptr{Void}),conn,proc,arg)
end

function PQregisterThreadLock(newhandler::pgthreadlock_t)
    ccall((:PQregisterThreadLock,libpq),pgthreadlock_t,(pgthreadlock_t,),newhandler)
end

function PQexec(conn,query)
    ccall((:PQexec,libpq),Ptr{PGresult},(Ptr{PGconn},Cstring),conn,query)
end

function PQexecParams(conn,command,nParams::Cint,paramTypes,paramValues,paramLengths,paramFormats,resultFormat::Cint)
    ccall((:PQexecParams,libpq),Ptr{PGresult},(Ptr{PGconn},Cstring,Cint,Ptr{Oid},Ptr{Cstring},Ptr{Cint},Ptr{Cint},Cint),conn,command,nParams,paramTypes,paramValues,paramLengths,paramFormats,resultFormat)
end

function PQprepare(conn,stmtName,query,nParams::Cint,paramTypes)
    ccall((:PQprepare,libpq),Ptr{PGresult},(Ptr{PGconn},Cstring,Cstring,Cint,Ptr{Oid}),conn,stmtName,query,nParams,paramTypes)
end

function PQexecPrepared(conn,stmtName,nParams::Cint,paramValues,paramLengths,paramFormats,resultFormat::Cint)
    ccall((:PQexecPrepared,libpq),Ptr{PGresult},(Ptr{PGconn},Cstring,Cint,Ptr{Cstring},Ptr{Cint},Ptr{Cint},Cint),conn,stmtName,nParams,paramValues,paramLengths,paramFormats,resultFormat)
end

function PQsendQuery(conn,query)
    ccall((:PQsendQuery,libpq),Cint,(Ptr{PGconn},Cstring),conn,query)
end

function PQsendQueryParams(conn,command,nParams::Cint,paramTypes,paramValues,paramLengths,paramFormats,resultFormat::Cint)
    ccall((:PQsendQueryParams,libpq),Cint,(Ptr{PGconn},Cstring,Cint,Ptr{Oid},Ptr{Cstring},Ptr{Cint},Ptr{Cint},Cint),conn,command,nParams,paramTypes,paramValues,paramLengths,paramFormats,resultFormat)
end

function PQsendPrepare(conn,stmtName,query,nParams::Cint,paramTypes)
    ccall((:PQsendPrepare,libpq),Cint,(Ptr{PGconn},Cstring,Cstring,Cint,Ptr{Oid}),conn,stmtName,query,nParams,paramTypes)
end

function PQsendQueryPrepared(conn,stmtName,nParams::Cint,paramValues,paramLengths,paramFormats,resultFormat::Cint)
    ccall((:PQsendQueryPrepared,libpq),Cint,(Ptr{PGconn},Cstring,Cint,Ptr{Cstring},Ptr{Cint},Ptr{Cint},Cint),conn,stmtName,nParams,paramValues,paramLengths,paramFormats,resultFormat)
end

function PQsetSingleRowMode(conn)
    ccall((:PQsetSingleRowMode,libpq),Cint,(Ptr{PGconn},),conn)
end

function PQgetResult(conn)
    ccall((:PQgetResult,libpq),Ptr{PGresult},(Ptr{PGconn},),conn)
end

function PQisBusy(conn)
    ccall((:PQisBusy,libpq),Cint,(Ptr{PGconn},),conn)
end

function PQconsumeInput(conn)
    ccall((:PQconsumeInput,libpq),Cint,(Ptr{PGconn},),conn)
end

function PQnotifies(conn)
    ccall((:PQnotifies,libpq),Ptr{PGnotify},(Ptr{PGconn},),conn)
end

function PQputCopyData(conn,buffer,nbytes::Cint)
    ccall((:PQputCopyData,libpq),Cint,(Ptr{PGconn},Cstring,Cint),conn,buffer,nbytes)
end

function PQputCopyEnd(conn,errormsg)
    ccall((:PQputCopyEnd,libpq),Cint,(Ptr{PGconn},Cstring),conn,errormsg)
end

function PQgetCopyData(conn,buffer,async::Cint)
    ccall((:PQgetCopyData,libpq),Cint,(Ptr{PGconn},Ptr{Cstring},Cint),conn,buffer,async)
end

function PQgetline(conn,string,length::Cint)
    ccall((:PQgetline,libpq),Cint,(Ptr{PGconn},Cstring,Cint),conn,string,length)
end

function PQputline(conn,string)
    ccall((:PQputline,libpq),Cint,(Ptr{PGconn},Cstring),conn,string)
end

function PQgetlineAsync(conn,buffer,bufsize::Cint)
    ccall((:PQgetlineAsync,libpq),Cint,(Ptr{PGconn},Cstring,Cint),conn,buffer,bufsize)
end

function PQputnbytes(conn,buffer,nbytes::Cint)
    ccall((:PQputnbytes,libpq),Cint,(Ptr{PGconn},Cstring,Cint),conn,buffer,nbytes)
end

function PQendcopy(conn)
    ccall((:PQendcopy,libpq),Cint,(Ptr{PGconn},),conn)
end

function PQsetnonblocking(conn,arg::Cint)
    ccall((:PQsetnonblocking,libpq),Cint,(Ptr{PGconn},Cint),conn,arg)
end

function PQisnonblocking(conn)
    ccall((:PQisnonblocking,libpq),Cint,(Ptr{PGconn},),conn)
end

function PQisthreadsafe()
    ccall((:PQisthreadsafe,libpq),Cint,())
end

function PQping(conninfo)
    ccall((:PQping,libpq),PGPing,(Cstring,),conninfo)
end

function PQpingParams(keywords,values,expand_dbname::Cint)
    ccall((:PQpingParams,libpq),PGPing,(Ptr{Cstring},Ptr{Cstring},Cint),keywords,values,expand_dbname)
end

function PQflush(conn)
    ccall((:PQflush,libpq),Cint,(Ptr{PGconn},),conn)
end

function PQfn(conn,fnid::Cint,result_buf,result_len,result_is_int::Cint,args,nargs::Cint)
    ccall((:PQfn,libpq),Ptr{PGresult},(Ptr{PGconn},Cint,Ptr{Cint},Ptr{Cint},Cint,Ptr{PQArgBlock},Cint),conn,fnid,result_buf,result_len,result_is_int,args,nargs)
end

function PQresultStatus(res)
    ccall((:PQresultStatus,libpq),ExecStatusType,(Ptr{PGresult},),res)
end

function PQresStatus(status::ExecStatusType)
    ccall((:PQresStatus,libpq),Cstring,(ExecStatusType,),status)
end

function PQresultErrorMessage(res)
    ccall((:PQresultErrorMessage,libpq),Cstring,(Ptr{PGresult},),res)
end

function PQresultErrorField(res,fieldcode::Cint)
    ccall((:PQresultErrorField,libpq),Cstring,(Ptr{PGresult},Cint),res,fieldcode)
end

function PQntuples(res)
    ccall((:PQntuples,libpq),Cint,(Ptr{PGresult},),res)
end

function PQnfields(res)
    ccall((:PQnfields,libpq),Cint,(Ptr{PGresult},),res)
end

function PQbinaryTuples(res)
    ccall((:PQbinaryTuples,libpq),Cint,(Ptr{PGresult},),res)
end

function PQfname(res,field_num::Cint)
    ccall((:PQfname,libpq),Cstring,(Ptr{PGresult},Cint),res,field_num)
end

function PQfnumber(res,field_name)
    ccall((:PQfnumber,libpq),Cint,(Ptr{PGresult},Cstring),res,field_name)
end

function PQftable(res,field_num::Cint)
    ccall((:PQftable,libpq),Oid,(Ptr{PGresult},Cint),res,field_num)
end

function PQftablecol(res,field_num::Cint)
    ccall((:PQftablecol,libpq),Cint,(Ptr{PGresult},Cint),res,field_num)
end

function PQfformat(res,field_num::Cint)
    ccall((:PQfformat,libpq),Cint,(Ptr{PGresult},Cint),res,field_num)
end

function PQftype(res,field_num::Cint)
    ccall((:PQftype,libpq),Oid,(Ptr{PGresult},Cint),res,field_num)
end

function PQfsize(res,field_num::Cint)
    ccall((:PQfsize,libpq),Cint,(Ptr{PGresult},Cint),res,field_num)
end

function PQfmod(res,field_num::Cint)
    ccall((:PQfmod,libpq),Cint,(Ptr{PGresult},Cint),res,field_num)
end

function PQcmdStatus(res)
    ccall((:PQcmdStatus,libpq),Cstring,(Ptr{PGresult},),res)
end

function PQoidStatus(res)
    ccall((:PQoidStatus,libpq),Cstring,(Ptr{PGresult},),res)
end

function PQoidValue(res)
    ccall((:PQoidValue,libpq),Oid,(Ptr{PGresult},),res)
end

function PQcmdTuples(res)
    ccall((:PQcmdTuples,libpq),Cstring,(Ptr{PGresult},),res)
end

function PQgetvalue(res,tup_num::Cint,field_num::Cint)
    ccall((:PQgetvalue,libpq),Cstring,(Ptr{PGresult},Cint,Cint),res,tup_num,field_num)
end

function PQgetlength(res,tup_num::Cint,field_num::Cint)
    ccall((:PQgetlength,libpq),Cint,(Ptr{PGresult},Cint,Cint),res,tup_num,field_num)
end

function PQgetisnull(res,tup_num::Cint,field_num::Cint)
    ccall((:PQgetisnull,libpq),Cint,(Ptr{PGresult},Cint,Cint),res,tup_num,field_num)
end

function PQnparams(res)
    ccall((:PQnparams,libpq),Cint,(Ptr{PGresult},),res)
end

function PQparamtype(res,param_num::Cint)
    ccall((:PQparamtype,libpq),Oid,(Ptr{PGresult},Cint),res,param_num)
end

function PQdescribePrepared(conn,stmt)
    ccall((:PQdescribePrepared,libpq),Ptr{PGresult},(Ptr{PGconn},Cstring),conn,stmt)
end

function PQdescribePortal(conn,portal)
    ccall((:PQdescribePortal,libpq),Ptr{PGresult},(Ptr{PGconn},Cstring),conn,portal)
end

function PQsendDescribePrepared(conn,stmt)
    ccall((:PQsendDescribePrepared,libpq),Cint,(Ptr{PGconn},Cstring),conn,stmt)
end

function PQsendDescribePortal(conn,portal)
    ccall((:PQsendDescribePortal,libpq),Cint,(Ptr{PGconn},Cstring),conn,portal)
end

function PQclear(res)
    ccall((:PQclear,libpq),Void,(Ptr{PGresult},),res)
end

function PQfreemem(ptr)
    ccall((:PQfreemem,libpq),Void,(Ptr{Void},),ptr)
end

function PQmakeEmptyPGresult(conn,status::ExecStatusType)
    ccall((:PQmakeEmptyPGresult,libpq),Ptr{PGresult},(Ptr{PGconn},ExecStatusType),conn,status)
end

function PQcopyResult(src,flags::Cint)
    ccall((:PQcopyResult,libpq),Ptr{PGresult},(Ptr{PGresult},Cint),src,flags)
end

function PQsetResultAttrs(res,numAttributes::Cint,attDescs)
    ccall((:PQsetResultAttrs,libpq),Cint,(Ptr{PGresult},Cint,Ptr{PGresAttDesc}),res,numAttributes,attDescs)
end

function PQresultAlloc(res,nBytes::Cint)
    ccall((:PQresultAlloc,libpq),Ptr{Void},(Ptr{PGresult},Cint),res,nBytes)
end

function PQsetvalue(res,tup_num::Cint,field_num::Cint,value,len::Cint)
    ccall((:PQsetvalue,libpq),Cint,(Ptr{PGresult},Cint,Cint,Cstring,Cint),res,tup_num,field_num,value,len)
end

function PQescapeStringConn()
    ccall((:PQescapeStringConn,libpq),Cint,())
end

function PQescapeLiteral(conn,str,len::Cint)
    ccall((:PQescapeLiteral,libpq),Cstring,(Ptr{PGconn},Cstring,Cint),conn,str,len)
end

function PQescapeIdentifier(conn,str,len::Cint)
    ccall((:PQescapeIdentifier,libpq),Cstring,(Ptr{PGconn},Cstring,Cint),conn,str,len)
end

function PQescapeByteaConn(conn,from,from_length::Cint,to_length)
    ccall((:PQescapeByteaConn,libpq),Ptr{Cuchar},(Ptr{PGconn},Ptr{Cuchar},Cint,Ptr{Cint}),conn,from,from_length,to_length)
end

function PQunescapeBytea(strtext,retbuflen)
    ccall((:PQunescapeBytea,libpq),Ptr{Cuchar},(Ptr{Cuchar},Ptr{Cint}),strtext,retbuflen)
end

function PQescapeString()
    ccall((:PQescapeString,libpq),Cint,())
end

function PQescapeBytea(from,from_length::Cint,to_length)
    ccall((:PQescapeBytea,libpq),Ptr{Cuchar},(Ptr{Cuchar},Cint,Ptr{Cint}),from,from_length,to_length)
end

function PQprint(fout,res,ps)
    ccall((:PQprint,libpq),Void,(Ptr{FILE},Ptr{PGresult},Ptr{PQprintOpt}),fout,res,ps)
end

function PQdisplayTuples(res,fp,fillAlign::Cint,fieldSep,printHeader::Cint,quiet::Cint)
    ccall((:PQdisplayTuples,libpq),Void,(Ptr{PGresult},Ptr{FILE},Cint,Cstring,Cint,Cint),res,fp,fillAlign,fieldSep,printHeader,quiet)
end

function PQprintTuples(res,fout,printAttName::Cint,terseOutput::Cint,width::Cint)
    ccall((:PQprintTuples,libpq),Void,(Ptr{PGresult},Ptr{FILE},Cint,Cint,Cint),res,fout,printAttName,terseOutput,width)
end

function lo_open(conn,lobjId::Oid,mode::Cint)
    ccall((:lo_open,libpq),Cint,(Ptr{PGconn},Oid,Cint),conn,lobjId,mode)
end

function lo_close(conn,fd::Cint)
    ccall((:lo_close,libpq),Cint,(Ptr{PGconn},Cint),conn,fd)
end

function lo_read(conn,fd::Cint,buf,len::Cint)
    ccall((:lo_read,libpq),Cint,(Ptr{PGconn},Cint,Cstring,Cint),conn,fd,buf,len)
end

function lo_write(conn,fd::Cint,buf,len::Cint)
    ccall((:lo_write,libpq),Cint,(Ptr{PGconn},Cint,Cstring,Cint),conn,fd,buf,len)
end

function lo_lseek(conn,fd::Cint,offset::Cint,whence::Cint)
    ccall((:lo_lseek,libpq),Cint,(Ptr{PGconn},Cint,Cint,Cint),conn,fd,offset,whence)
end

function lo_lseek64(conn,fd::Cint,offset::pg_int64,whence::Cint)
    ccall((:lo_lseek64,libpq),pg_int64,(Ptr{PGconn},Cint,pg_int64,Cint),conn,fd,offset,whence)
end

function lo_creat(conn,mode::Cint)
    ccall((:lo_creat,libpq),Oid,(Ptr{PGconn},Cint),conn,mode)
end

function lo_create(conn,lobjId::Oid)
    ccall((:lo_create,libpq),Oid,(Ptr{PGconn},Oid),conn,lobjId)
end

function lo_tell(conn,fd::Cint)
    ccall((:lo_tell,libpq),Cint,(Ptr{PGconn},Cint),conn,fd)
end

function lo_tell64(conn,fd::Cint)
    ccall((:lo_tell64,libpq),pg_int64,(Ptr{PGconn},Cint),conn,fd)
end

function lo_truncate(conn,fd::Cint,len::Cint)
    ccall((:lo_truncate,libpq),Cint,(Ptr{PGconn},Cint,Cint),conn,fd,len)
end

function lo_truncate64(conn,fd::Cint,len::pg_int64)
    ccall((:lo_truncate64,libpq),Cint,(Ptr{PGconn},Cint,pg_int64),conn,fd,len)
end

function lo_unlink(conn,lobjId::Oid)
    ccall((:lo_unlink,libpq),Cint,(Ptr{PGconn},Oid),conn,lobjId)
end

function lo_import(conn,filename)
    ccall((:lo_import,libpq),Oid,(Ptr{PGconn},Cstring),conn,filename)
end

function lo_import_with_oid(conn,filename,lobjId::Oid)
    ccall((:lo_import_with_oid,libpq),Oid,(Ptr{PGconn},Cstring,Oid),conn,filename,lobjId)
end

function lo_export(conn,lobjId::Oid,filename)
    ccall((:lo_export,libpq),Cint,(Ptr{PGconn},Oid,Cstring),conn,lobjId,filename)
end

function PQlibVersion()
    ccall((:PQlibVersion,libpq),Cint,())
end

function PQmblen(s,encoding::Cint)
    ccall((:PQmblen,libpq),Cint,(Cstring,Cint),s,encoding)
end

function PQdsplen(s,encoding::Cint)
    ccall((:PQdsplen,libpq),Cint,(Cstring,Cint),s,encoding)
end

function PQenv2encoding()
    ccall((:PQenv2encoding,libpq),Cint,())
end

function PQencryptPassword(passwd,user)
    ccall((:PQencryptPassword,libpq),Cstring,(Cstring,Cstring),passwd,user)
end

function pg_char_to_encoding(name)
    ccall((:pg_char_to_encoding,libpq),Cint,(Cstring,),name)
end

function pg_encoding_to_char(encoding::Cint)
    ccall((:pg_encoding_to_char,libpq),Cstring,(Cint,),encoding)
end

function pg_valid_server_encoding_id(encoding::Cint)
    ccall((:pg_valid_server_encoding_id,libpq),Cint,(Cint,),encoding)
end
