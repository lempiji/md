module commands.main;

import commonmarkd.md4c;
import jcli;
import std.algorithm;
import std.array;
import std.container.array : Array;
import std.conv;
import std.range;
import std.stdio;
import std.string;
import std.typecons;

@CommandDefault("Execute code block in markdown.")
struct DefaultCommand
{
    @ArgPositional("file", "Markdown file (.md)")
    Nullable!string file;

    @ArgGroup("Options")
    {
        @ArgNamed("quiet|q", "Only print warnings and errors")
        @(ArgConfig.parseAsFlag)
        bool quiet;

        @ArgNamed("verbose|v", "Print diagnostic output")
        @(ArgConfig.parseAsFlag)
        bool verbose;

        @ArgNamed("show-lang", "Print language prefix for begin/end logs")
        @(ArgConfig.parseAsFlag)
        bool showLanguage;

        @ArgNamed("dependency|d", "Adds a DUB dependency into the D source. May be either in format `name` (version \"*\") or `name@version` to download an exact version or version range.")
        @(ArgConfig.aggregate | ArgConfig.optional)
        string[] dubDependencies;

        @ArgNamed("dubsdl", "Adds a dub.sdl package recipe line into the generated D source file.")
        @(ArgConfig.aggregate | ArgConfig.optional)
        string[] dubInstructions;

        @ArgNamed("build", "Specifies the type of build to perform. (debug, release, unittest, profile, cov, etc.)")
        @(ArgConfig.optional)
        Nullable!string build;

        @ArgNamed("compiler", "Specifies the compiler binary to use. (dmd, gdc, ldc2, gdmd, ldmd)")
        @(ArgConfig.optional)
        Nullable!string compiler;

        @ArgNamed("arch", "Force a different architecture (e.g. x86 or x86_64)")
        @(ArgConfig.optional)
        Nullable!string arch;

        @ArgNamed("filter", "Filter blocks by name")
        @(ArgConfig.aggregate | ArgConfig.optional)
        string[] filters;

        @ArgNamed("buildOnly|no-run", "Build the code without running it")
        @(ArgConfig.parseAsFlag)
        bool buildOnly;
    }

    int onExecute()
    {
        if (filters.length > 0)
        {
            writeln("Filtering blocks by: ", filters);
        }

        if (!dubInstructions.length)
        {
            dubInstructions = [];
            auto packageName = loadCurrentProjectName();
            if (verbose)
                writeln("packageName: ", packageName);
            if (packageName.length)
            {
                import std.file : getcwd;

                dubInstructions ~= format!`dependency "%s" path="%s"`(packageName,
                    escapeSystemPath(getcwd()));
            }
        }

        foreach (string depName; dubDependencies)
        {
            auto parts = depName.findSplit("@");
            dubInstructions ~= format!`dependency "%s" version="%s"`(
                parts[0],
                parts[2].length ? parts[2] : "*"
            );
        }

        string filepath = !file.isNull ? file.get() : "README.md";
        auto result = parseMarkdown(filepath);

        Appender!(string)[string] namedBlocks;
        NamedExecutionUnit[] orderedUnits;
        string[] singleBlocks;
        string[] globalBlocks;
        foreach (block; result.blocks)
        {
            if (isDisabledBlock(block))
                continue;

            auto language = normalizeLanguage(block.lang);
            if (!isSupportedLanguage(language))
                continue;

            if (isDLanguage(language) && isSingleBlock(block))
            {
                singleBlocks ~= block.code[].to!string();
                continue;
            }
            if (isDLanguage(language) && isGlobalBlock(block))
            {
                globalBlocks ~= block.code[].to!string();
                continue;
            }

            auto names = getBlockNames(block);
            if (filters.length > 0)
            {
                names = filterBlockNames(names, filters);
                if (names.length == 0)
                    continue;
            }

            foreach (name; names)
            {
                const key = makeUnitKey(language, name);
                if (!(key in namedBlocks))
                {
                    namedBlocks[key] = appender!string;
                    orderedUnits ~= NamedExecutionUnit(language, name);
                }
                namedBlocks[key].put(block.code[]);
            }
        }

        // evaluate all
        auto runSettings = DubRunSettings(build, compiler, arch);

        size_t totalCount;
        size_t errorCount;
        foreach (unit; orderedUnits)
        {
            totalCount++;
            auto namedLabel = formatNamedLogLabel(unit.language, unit.name, showLanguage);
            if (!quiet)
                writeln("begin: ", namedLabel);
            scope (exit)
                if (!quiet)
                    writeln("end: ", namedLabel);

            const source = namedBlocks[makeUnitKey(unit.language, unit.name)].data;
            int status;
            if (isDLanguage(unit.language))
            {
                status = evaluateD(source, dubInstructions, BlockType.Single, runSettings, verbose, buildOnly);
            }
            else
            {
                status = evaluateShell(source, unit.language, verbose, buildOnly);
            }
            errorCount += status != 0;
        }

        foreach (i, source; singleBlocks)
        {
            totalCount++;
            auto singleLabel = formatDIndexedLogLabel(i, showLanguage);
            if (!quiet)
                writeln("begin single: ", singleLabel);
            scope (exit)
                if (!quiet)
                    writeln("end single: ", singleLabel);

            const status = evaluateD(source, dubInstructions, BlockType.Single, runSettings, verbose, buildOnly);
            errorCount += status != 0;
        }

        foreach (i, source; globalBlocks)
        {
            totalCount++;
            auto globalLabel = formatDIndexedLogLabel(i, showLanguage);
            if (!quiet)
                writeln("begin global :", globalLabel);
            scope (exit)
                if (!quiet)
                    writeln("end global :", globalLabel);

            const status = evaluateD(source, dubInstructions, BlockType.Global, runSettings, verbose, buildOnly);
            errorCount += status != 0;
        }

        if (!quiet)
            stdout.writefln!"Total blocks: %d"(totalCount);
        if (errorCount != 0)
        {
            stderr.writefln!"Errors: %d"(errorCount);
            return 1;
        }

        if (!quiet)
            stdout.writeln("Success all blocks.");
        return 0;
    }
}

struct ParseResult
{
    int status;
    Code[] blocks;
}

ParseResult parseMarkdown(in const(char)[] filepath)
{
    import std.file : readText;

    auto text = readText(filepath);

    MD_PARSER parser;
    parser.enter_block = (MD_BLOCKTYPE type, void* detail, void* userdata) {
        CodeAggregator* aggregator = cast(CodeAggregator*) userdata;
        return aggregator.enterBlock(type, detail);
    };
    parser.leave_block = (MD_BLOCKTYPE type, void* detail, void* userdata) {
        CodeAggregator* aggregator = cast(CodeAggregator*) userdata;
        return aggregator.leaveBlock(type, detail);
    };
    parser.enter_span = (MD_BLOCKTYPE type, void*, void*) {
        // debug writeln("enter_span: ", type);
        return 0;
    };
    parser.leave_span = (MD_BLOCKTYPE type, void*, void*) {
        // debug writeln("leave_span: ", type);
        return 0;
    };
    parser.text = (MD_TEXTTYPE type, const(MD_CHAR*) text, MD_SIZE size, void* userdata) {
        CodeAggregator* aggregator = cast(CodeAggregator*) userdata;
        return aggregator.text(type, text, size);
    };

    CodeAggregator aggregator;
    auto status = md_parse(text.ptr, cast(uint) text.length, &parser, &aggregator);

    return ParseResult(status, aggregator.codes[].array());
}

struct Code
{
    const(char)[] lang;
    const(char)[] info;
    Array!char code;
}

struct NamedExecutionUnit
{
    string language;
    string name;
}

string makeUnitKey(string language, string name)
{
    return language ~ "\x1f" ~ name;
}

string normalizeLanguage(const(char)[] language)
{
    if (language.length == 0)
        return "";
    return language.to!string.toLower();
}

bool isDLanguage(string language)
{
    return language == "d";
}

bool isSupportedLanguage(string language)
{
    return isDLanguage(language) || language == "sh" || language == "bash";
}

string formatNamedLogLabel(string language, string name, bool showLanguage)
{
    return showLanguage ? language ~ ":" ~ name : name;
}

string formatDIndexedLogLabel(size_t index, bool showLanguage)
{
    return showLanguage ? "d:" ~ to!string(index) : to!string(index);
}

struct CodeAggregator
{
    bool isCode;
    Code current;
    Array!Code codes;

    int enterBlock()(MD_BLOCKTYPE type, void* detail)
    {
        isCode = type == MD_BLOCK_CODE;
        if (isCode && detail !is null)
        {
            MD_BLOCK_CODE_DETAIL* data = cast(MD_BLOCK_CODE_DETAIL*) detail;
            setAttribute(current.lang, data.lang, 0);
            setAttribute(current.info, data.info, data.lang.size + 1);
            current.code.clear();
        }
        return 0;
    }

    int leaveBlock()(MD_BLOCKTYPE type, void* detail)
    {
        if (isCode)
        {
            codes.insertBack(current);
        }
        isCode = false;
        return 0;
    }

    int text()(MD_TEXTTYPE type, const(MD_CHAR*) text, MD_SIZE size)
    {
        if (isCode && size != 0)
        {
            current.code.reserve(size);
            foreach (i; 0 .. size)
            {
                current.code.insertBack(text[i]);
            }
        }
        return 0;
    }
}

void setAttribute()(ref const(char)[] data, MD_ATTRIBUTE attr, size_t offset = 0) nothrow @nogc
{
    import std.algorithm : min;

    if (attr.text !is null && attr.size != 0)
    {
        offset = min(offset, attr.size);
        data = attr.text[offset .. attr.size];
    }
    else
        data = null;
}

bool isDisabledBlock(const ref Code code)
{
    import std.regex : regex, matchFirst;

    auto pat = regex(`(?<=^|\s)disabled(?=\s|$)`);
    if (auto m = matchFirst(code.info, pat))
    {
        return true;
    }
    return false;
}

bool isSingleBlock(const ref Code code)
{
    import std.regex : regex, matchFirst;

    auto pat = regex(`(?<=^|\s)single(?=\s|$)`);
    if (auto m = matchFirst(code.info, pat))
    {
        return true;
    }
    return false;
}

bool isGlobalBlock(const ref Code code)
{
    import std.regex : regex, matchFirst;

    auto pat = regex(`(?<=^|\s)global(?=\s|$)`);
    if (auto m = matchFirst(code.info, pat))
    {
        return true;
    }
    return false;
}

bool isFilteredBlock(const ref Code code, string[] filters)
{
    return filterBlockNames(getBlockNames(code), filters).length > 0;
}

string[] getBlockNames(const ref Code code)
{
    import std.regex : regex, matchAll;

    auto pat = regex(`(?<=^|\s)name=(\w+)(?=\s|$)`);
    bool[string] seen;
    string[] names;

    foreach (m; matchAll(code.info, pat))
    {
        if (m[1].length != 0)
        {
            auto name = m[1].idup;
            if (name in seen)
                continue;

            seen[name] = true;
            names ~= name;
        }
    }

    if (names.length == 0)
        names ~= "main";

    return names;
}

string[] filterBlockNames(string[] blockNames, string[] filters)
{
    string[] result;
    foreach (name; blockNames)
    {
        foreach (filterName; filters)
        {
            if (name == filterName)
            {
                result ~= name;
                break;
            }
        }
    }

    return result;
}

unittest
{
    Code block;
    block.info = "name=test1 name=test2";
    assert(getBlockNames(block) == ["test1", "test2"]);
}

unittest
{
    Code block;
    block.info = "name=test1 name=test1";
    assert(getBlockNames(block) == ["test1"]);
}

unittest
{
    Code block;
    block.info = "single global";
    assert(getBlockNames(block) == ["main"]);
}

unittest
{
    Code block;
    block.info = "name=test1 name=test2";
    assert(filterBlockNames(getBlockNames(block), ["test1"]) == ["test1"]);
    assert(filterBlockNames(getBlockNames(block), ["test2"]) == ["test2"]);
    assert(filterBlockNames(getBlockNames(block), ["test3"]).length == 0);
}

unittest
{
    Code block;
    block.info = "name=test1 name=test2";
    assert(isFilteredBlock(block, ["test2"]));
    assert(!isFilteredBlock(block, ["test3"]));
}

unittest
{
    assert(isSupportedLanguage("d"));
    assert(isSupportedLanguage(normalizeLanguage("D")));
    assert(isSupportedLanguage("sh"));
    assert(isSupportedLanguage("bash"));
    assert(!isSupportedLanguage("python"));
    assert(normalizeLanguage("BASH") == "bash");
}

unittest
{
    assert(makeUnitKey("d", "main") == "d\x1fmain");
}

unittest
{
    assert(formatNamedLogLabel("sh", "test", false) == "test");
    assert(formatNamedLogLabel("sh", "test", true) == "sh:test");
    assert(formatDIndexedLogLabel(0, false) == "0");
    assert(formatDIndexedLogLabel(1, true) == "d:1");
}

enum BlockType
{
    Single,
    Global,
}

struct DubRunSettings
{
    Nullable!string build;
    Nullable!string compiler;
    Nullable!string arch;

    void appendAdditionalArgs(ref string[] args)
    {
        if (!build.isNull())
        {
            args ~= "--build";
            args ~= build.get();
        }

        if (!compiler.isNull())
        {
            args ~= "--compiler";
            args ~= compiler.get();
        }

        if (!arch.isNull())
        {
            args ~= "--arch";
            args ~= arch.get();
        }
    }
}

int evaluateD(string source, string[] dubInstructions, BlockType type, DubRunSettings settings, bool verbose, bool skipRun)
{
    import std.conv : text, to;
    import std.digest : toHexString, LetterCase;
    import std.digest.murmurhash : MurmurHash3;
    import std.file : mkdirRecurse, tempDir;
    import std.path : buildNormalizedPath;
    import std.process : spawnProcess, wait;
    import std.stdio : stdin, stdout;

    auto workDir = buildNormalizedPath(tempDir(), ".md");
    mkdirRecurse(workDir);

    MurmurHash3!128 hasher;
    hasher.start();
    hasher.put(source.representation);
    hasher.put(dubInstructions.join("\n").representation);
    auto hash = hasher.finish();

    auto moduleName = text("md_", hash.toHexString!(LetterCase.lower)());
    auto filename = moduleName ~ ".d";
    auto tempFilePath = buildNormalizedPath(workDir, filename);
    if (verbose)
    {
        writeln("tempFilePath: ", tempFilePath);
        writeln("tempFileName: ", filename);
    }

    {
        auto sourceFile = File(tempFilePath, "w");
        sourceFile.writeln("/+ dub.sdl:");
        foreach (instr; dubInstructions)
            sourceFile.writeln(instr);
        sourceFile.writeln("+/");
        if (type == BlockType.Single)
        {
            sourceFile.writeln("module ", moduleName, ";");
            sourceFile.writeln("void main() {");
        }
        sourceFile.writeln(source);
        if (type == BlockType.Single)
        {
            sourceFile.writeln("}");
        }
        sourceFile.flush();
    }

    string[] args = ["dub", skipRun ? "build" : "run", "--single"];
    if (!verbose)
        args ~= "--quiet";

    // compiler, arch
    settings.appendAdditionalArgs(args);

    args ~= ["--root", workDir, filename];

    if (verbose)
        writeln("dub args: ", args);

    auto result = spawnProcess(args, stdin, stdout);
    return wait(result);
}

int evaluateShell(string source, string shellKind, bool verbose, bool skipRun)
{
    import std.conv : text;
    import std.digest : toHexString, LetterCase;
    import std.digest.murmurhash : MurmurHash3;
    import std.file : mkdirRecurse, tempDir;
    import std.path : buildNormalizedPath;
    import std.process : spawnProcess, wait;
    import std.stdio : stdin, stdout, stderr;

    auto workDir = buildNormalizedPath(tempDir(), ".md");
    mkdirRecurse(workDir);

    MurmurHash3!128 hasher;
    hasher.start();
    hasher.put(source.representation);
    hasher.put(shellKind.representation);
    auto hash = hasher.finish();

    auto scriptName = text("md_", hash.toHexString!(LetterCase.lower)(), ".sh");
    auto scriptPath = buildNormalizedPath(workDir, scriptName);
    if (verbose)
    {
        writeln("scriptPath: ", scriptPath);
    }

    {
        auto sourceFile = File(scriptPath, "w");
        sourceFile.write(source);
        sourceFile.flush();
    }

    if (skipRun)
    {
        if (verbose)
            writeln("skip run for ", shellKind, " script by --buildOnly");
        return 0;
    }

    string[] args;
    if (shellKind == "bash")
    {
        args = ["bash", "-eu", "-o", "pipefail", scriptPath];
    }
    else
    {
        args = ["sh", "-eu", scriptPath];
    }

    if (verbose)
        writeln("shell args: ", args);

    auto result = spawnProcess(args, stdin, stdout, stderr);
    return wait(result);
}

string loadCurrentProjectName()
{
    import std.file : exists;

    if (exists("dub.json"))
    {
        import std.json : parseJSON;
        import std.file : readText;

        auto jsonText = readText("dub.json");
        auto json = parseJSON(jsonText);

        return json["name"].get!string();
    }

    if (exists("dub.sdl"))
    {
        import std.regex : ctRegex, matchFirst;

        enum pattern = ctRegex!`^name "([-\w]+)"$`;
        auto f = File("dub.sdl", "r");
        foreach (line; f.byLine())
        {
            if (auto m = matchFirst(line, pattern))
            {
                import std.conv : to;

                return m[1].to!string();
            }
        }
    }

    return null;
}

string escapeSystemPath(string path)
{
    import std.path : dirSeparator;
    import std.array : replace;

    version (Windows)
    {
        return replace(path, dirSeparator, dirSeparator ~ dirSeparator);
    }
    else
    {
        return path;
    }
}
