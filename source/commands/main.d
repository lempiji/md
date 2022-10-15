module commands.main;

import commonmarkd.md4c;
import jcli;
import std.array;
import std.container.array : Array;
import std.stdio;
import std.typecons;
import std.conv;
import std.range;

@CommandDefault("Execute code block in markdown.")
struct DefaultCommand
{
    @ArgPositional("file", "Markdown file (.md)")
    Nullable!string file;

    @ArgGroup("Options")
    {
        @ArgNamed("quiet|q", "Only print warnings and errors")
        Nullable!bool quiet;

        @ArgNamed("verbose|v", "Print diagnostic output")
        Nullable!bool verbose;
    }

    int onExecute()
    {
        auto packageName = loadCurrentProjectName();
        if (verbose.isTrue)
            writeln("packageName: ", packageName);

        string filepath = !file.isNull ? file.get() : "README.md";
        auto result = parseMarkdown(filepath);

        Appender!(string)[string] blocks;
        string[] singleBlocks;
        string[] globalBlocks;
        foreach (block; result.blocks)
        {
            if (block.lang == "d" || block.lang == "D")
            {
                if (isDisabledBlock(block))
                    continue;
                if (isSingleBlock(block))
                {
                    singleBlocks ~= block.code[].to!string();
                    continue;
                }
                if (isGlobalBlock(block))
                {
                    globalBlocks ~= block.code[].to!string();
                    continue;
                }

                auto name = getBlockName(block);
                if (!(name in blocks))
                {
                    blocks[name] = appender!string;
                }
                blocks[name].put(block.code[]);
            }
        }

        // evaluate all
        size_t totalCount;
        size_t errorCount;
        foreach (key, value; blocks)
        {
            totalCount++;
            if (!quiet.get(false))
                writeln("begin: ", key);
            scope (exit)
                if (!quiet.get(false))
                    writeln("end: ", key);

            const status = evaluate(value.data, packageName, BlockType.Single, verbose.isTrue);
            errorCount += status != 0;
        }

        foreach (i, source; singleBlocks)
        {
            totalCount++;
            if (!quiet.get(false))
                writeln("begin single: ", i);
            scope (exit)
                if (!quiet.get(false))
                    writeln("end single: ", i);

            const status = evaluate(source, packageName, BlockType.Single, verbose.isTrue);
            errorCount += status != 0;
        }

        foreach (i, source; globalBlocks)
        {
            totalCount++;
            if (!quiet.get(false))
                writeln("begin global :", i);
            scope (exit)
                if (!quiet.get(false))
                    writeln("end global :", i);

            const status = evaluate(source, packageName, BlockType.Global, verbose.isTrue);
            errorCount += status != 0;
        }

        if (!quiet.get(false))
            stdout.writefln!"Total blocks: %d"(totalCount);
        if (errorCount != 0)
        {
            stderr.writefln!"Errors: %d"(errorCount);
            return 1;
        }

        if (!quiet.get(false))
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

string getBlockName(const ref Code code)
{
    import std.regex : regex, matchFirst;

    auto pat = regex(`(?<=^|\s)name=(\w+)(?=\s|$)`);
    if (auto m = matchFirst(code.info, pat))
    {
        if (m[1].length != 0)
            return m[1].idup;
    }
    return "main";
}

enum BlockType
{
    Single,
    Global,
}

int evaluate(string source, string packageName, BlockType type, bool verbose)
{
    import std.stdio : stdin, stdout, stderr;
    import std.process : spawnProcess, wait;

    string header;
    if (packageName)
    {
        import std.format : format;
        import std.file : getcwd;

        header = format!"/+ dub.sdl:\n    dependency \"%s\" path=\"%s\"\n+/"(packageName,
                escapeSystemPath(getcwd()));
    }
    else
    {
        header = "/+ dub.sdl:\n +/";
    }

    import std.file : tempDir, write, remove, mkdirRecurse, chdir;
    import std.path : buildNormalizedPath;
    import std : toHexString, to, text;

    auto workDir = buildNormalizedPath(tempDir(), ".md");
    mkdirRecurse(workDir);

    import std.digest.murmurhash : MurmurHash3;
    import std.string : representation;

    MurmurHash3!128 hasher;
    hasher.start();
    hasher.put(source.representation);
    hasher.put(packageName.representation);
    auto hash = hasher.finish();

    auto moduleName = text("md_", hash.toHexString());
    auto filename = moduleName ~ ".d";
    auto tempFilePath = buildNormalizedPath(workDir, filename);
    if (verbose)
    {
        writeln("tempFilePath: ", tempFilePath);
        writeln("tempFileName: ", filename);
    }

    {
        auto sourceFile = File(tempFilePath, "w");
        sourceFile.writeln(header);
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

    string[] args = [
        "dub", "run", "--quiet", "--single", "--root", workDir, filename
    ];
    if (verbose)
        writeln("dub args: ", args);

    auto result = spawnProcess(args, stdin, stdout);
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

bool isTrue(in Nullable!bool value)
{
    if (value.isNull)
        return false;

    return value.get();
}
