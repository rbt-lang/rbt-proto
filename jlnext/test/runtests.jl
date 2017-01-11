#
# Executes the sample code in Markdown files.
#

import Base:
    show

function showlocation(io::IO, file::String, linenum::Int)
    location = file
    if linenum > 0
        location = "$location, line $linenum"
    end
    print(io, "[$location]")
end

function showindented(io::IO, block::String)
    for line in eachline(IOBuffer(block))
        if line == "\n"
            println(io)
        elseif line != ""
            print(io, " "^4, line)
        end
    end
end

immutable Pass
    file::String
    linenum::Int
    code::String
    output::String
end

function show(io::IO, pass::Pass)
    showlocation(io, pass.file, pass.linenum)
    println(io, " Passed")
    println(io, "Executed code:")
    showindented(io, pass.code)
    println(io)
    println(io, "Output:")
    showindented(io, pass.output)
    println(io)
end

immutable Fail
    file::String
    linenum::Int
    code::String
    expected::String
    actual::String
end

function show(io::IO, fail::Fail)
    showlocation(io, fail.file, fail.linenum)
    println(io, " Failed")
    println(io, "Executed code:")
    showindented(io, fail.code)
    println(io, "Expected output:")
    showindented(io, fail.expected)
    println(io)
    println(io, "Actual output:")
    showindented(io, fail.actual)
    println(io)
end

immutable Error
    file::String
    linenum::Int
    msg
end

function show(io::IO, error::Error)
    showlocation(io, error.file, error.linenum)
    print(io, " ")
    if isa(error.msg, Exception)
        showerror(io, error.msg)
    else
        print(io, error.msg)
    end
    println(io)
end

function main(files)
    passed = 0
    failed = 0
    errors = 0
    exit = 0
    for result in testfiles(files)
        if result !== nothing && !isa(result, Pass)
            exit = 1
            println("="^80)
            println(result)
        end
        if isa(result, Pass)
            passed += 1
        elseif isa(result, Fail)
            failed += 1
        elseif isa(result, Error)
            errors += 1
        end
    end
    println("="^80)
    if passed > 0
        println("TESTS PASSED: $passed")
    end
    if failed > 0
        println("TESTS FAILED: $failed")
    end
    if errors > 0
        println("ERRORS: $errors")
    end
    println()
    return exit
end

function testfiles(files)
    @task begin
        for file in files
            lines = String[]
            try
                append!(lines, readlines(file))
                push!(lines, "")
            catch msg
                produce(Error(file, 0, msg))
            end
            if !isempty(lines)
                foreach(produce, testmd(file, 0, lines))
            end
        end
    end
end

function testmd(file, start, lines)
    @task begin
        blockstart = 0
        blocklines = String[]
        fire = false
        fenced = false
        for (linenum, line) in enumerate(lines)
            linenum += start
            iseof = isempty(line)
            isblank = isempty(strip(line))
            isindent = startswith(line, " "^4)
            isfence = startswith(line, "```") || startswith(line, "~~~")
            if !fenced
                if iseof
                    fire = true
                elseif isfence
                    fire = true
                    fenced = true
                elseif isempty(blocklines) && isindent && !isblank
                    blockstart = linenum
                    push!(blocklines, line[5:end])
                elseif !isempty(blocklines) && isblank
                    push!(blocklines, "\n")
                elseif !isempty(blocklines) && isindent && !isblank
                    push!(blocklines, line[5:end])
                else
                    fire = true
                end
            elseif fenced
                if iseof
                    produce(Error(file, linenum, "Error: incomplete fenced code block"))
                elseif isfence
                    fire = true
                    fenced = false
                elseif isempty(blocklines) && !isblank
                    blockstart = linenum
                    push!(blocklines, line)
                elseif !isempty(blocklines)
                    push!(blocklines, line)
                end
            end
            if fire && !isempty(blocklines)
                push!(blocklines, "")
                foreach(produce, testjl(file, blockstart, blocklines))
                empty!(blocklines)
            end
            fire = false
        end
    end
end

function testjl(file, start, lines)
    @task begin
        casestart = 0
        codelines = String[]
        outlines = String[]
        commented = false
        fire = false
        for (linenum, line) in enumerate(lines)
            linenum += start
            isblank = isempty(strip(line))
            if commented && isempty(line)
                produce(Error(file, linenum, "Error: incomplete multiline output block"))
            elseif isempty(line)
                fire = true
            elseif commented && startswith(line, "=#")
                commented = false
                fire = true
            elseif commented
                push!(outlines, rstrip(line)*"\n")
            elseif line == "#->\n" || startswith(line, "#-> ")
                push!(outlines, rstrip(line[5:end])*"\n")
                fire = true
            elseif startswith(line, "#=>")
                commented = true
            elseif isempty(codelines) && !isblank
                casestart = linenum
                push!(codelines, line)
            elseif !isempty(codelines) || !isblank
                push!(codelines, line)
            end
            if fire && isempty(codelines) && !isempty(outlines)
                produce(Error(file, linenum, "Error: orphaned output block"))
                empty!(outlines)
            elseif fire && !isempty(codelines)
                produce(testcase(file, linenum, join(codelines), join(outlines)))
                empty!(codelines)
                empty!(outlines)
            end
            fire = false
        end
    end
end

const MODCACHE = Dict{String,Module}()

function testcase(file, start, code, output)
    body = try
        parse("begin\n$code\nend\n")
    catch err
        if isa(err, ParseError)
            return Error(file, start, "ParseError: $(err.msg)")
        end
        rethrow()
    end
    mod = get!(MODCACHE, file, Module(Symbol(file)))
    orig_stdout = STDOUT
    orig_stderr = STDERR
    pipe = Pipe()
    Base.link_pipe(pipe, julia_only_read=true, julia_only_write=true)
    redirect_stdout(pipe.in)
    redirect_stderr(pipe.in)
    pushdisplay(TextDisplay(IOContext(pipe.in, limit=true)))
    try
        ans = try
            eval(mod, body)
        catch err
            showerror(STDERR, err)
            nothing
        end
        if ans !== nothing && !isempty(output)
            show(IOContext(pipe.in, limit=true), ans)
        end
        println()
    finally
        popdisplay()
        redirect_stdout(orig_stdout)
        redirect_stderr(orig_stderr)
    end
    out = UInt8[]
    append!(out, readavailable(pipe))
    close(pipe)
    expected = rstrip(output)
    actual = rstrip(join(map(rstrip, eachline(IOBuffer(String(out)))), "\n"))
    return expected == actual || ismatch(asregex(expected), actual) ?
        Pass(file, start, code, expected) :
        Fail(file, start, code, expected, actual)
end

function asregex(pat::String)
    buf = IOBuffer()
    space = false
    skipspace = false
    print(buf, "\\A")
    for ch in pat
        if ch == ' '
            if !skipspace
                space = true
            end
        elseif ch == '…'
            print(buf, ".*")
            space = false
            skipspace = true
        elseif ch == '⋮'
            print(buf, "(.|\\n)*")
            space = false
            skipspace = true
        else
            if space
                print(buf, "\\s+")
                space = false
            end
            skipspace = false
            if !('0' <= ch <= '9' || 'a' <= ch <= 'z' || 'A' <= ch <= 'Z')
                print(buf, "\\")
            end
            print(buf, ch)
        end
    end
    print(buf, "\\z")
    return Regex(String(buf))
end

push!(LOAD_PATH, joinpath(dirname(@__FILE__), "../src"))

const INPUT = String[]
append!(INPUT, ARGS)
if isempty(INPUT)
    for (root, dirs, files) in walkdir(relpath(dirname(@__FILE__)))
        for file in files
            if endswith(file, ".md")
                push!(INPUT, joinpath(root, file))
            end
        end
    end
    sort!(INPUT)
end

exit(main(INPUT))

