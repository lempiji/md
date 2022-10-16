# md

[日本語](README.ja.md)

This is a tool to run Markdown code blocks.

This can be used by CI to guarantee that the samples written in the README will work.

Example repo: https://github.com/lempiji/sandbox-vuepress

## Usage

Run it as `dub fetch md` and `dub run md -- README.md`

Also, this `README.md` is executable.

You can configure how your generated D source file is run by passing in command line arguments to `md`:

__show help__

```
dub run md -- --help
```


## Features

The code block whose language is specified as `d` or `D` will be executed.

### Combine blocks

If there are multiple blocks as shown below, they will be combined and executed.

__block 1__

```d
import std;

auto message = "Hello, " ~ "Markdown!";
```

__block 2__

```d
writeln(message); // Hello, Markdown!
```

### Disabled block

Code blocks specified as `disabled` will not be executed, as shown below.

~~~
```d disabled
```
~~~

__disabled code block__

```d disabled
throw new Exception("disabled");
```

### Named block

Can give an independent scope to a block of code by giving it a name like the following.
Even if they are written separately, they will be combined like a block if they have the same name.

~~~
```d name=test
```
~~~

```d name=test
import std;

auto buf = iota(10).array();
writeln(buf);
```

If `name` is not specified, it is treated as the name `main`.

### Scoped block

To make a single block of code run independently without being combined with other blocks, give it the attribute `single`.

~~~
```d single
```
~~~

__single block__

```d single
import std;

auto message = "single code block";
writeln(message);
```

### Current package reference

If the current directory is a dub package, the dependency will be automatically added. (using a `"path"` based dependency)

For example, if this README is in the same directory as `md/dub.sdl`, then can import `commands.main` of `md`.

```d name=package_ref
import commands.main;
import std.stdio;

writeln("current package: ", loadCurrentProjectName());
```

### Additional dependencies

It's possible to specify `-d <packageName>` or `-d <packageName>@<versionString>` such as `-d mir-ion@~>2.0.16` to add further dependencies. (long name: `--dependency`)

### Instruction to dub.sdl

It's possible to specify `--dubsdl "<instruction>"` to add a dub.sdl recipe line into the generated file. This option can be used multiple times to add multiple lines.

Specifying this option disables the built-in CWD package dependency addition described above.

### Global

The normal code blocks are executed as if they were written in `void main() {}`. The source will be generated with `void main() {` and `}` appended before and after.

If you want the code block to be interpreted as a single source file, you can add a `global` attribute to the code block, which will not be combined with other code blocks as with the `single` attribute.

~~~
```d global
```
~~~

__single file__

```d global
import std;

void main()
{
    writeln("Hello, Markdown!");
}
```


## Othres

### How it works

Create a `.md` directory in the temp directory, generate the source in dub single file format, and run it with a command like `dub run --single md_xxx.md`.

It also automatically adds the following comment to the beginning of the source to achieve default package references.

```d disabled
/+ dub.sdl:
    dependency "md" path="C:\\work\md"
 +/
```

### Limits

#### UFCS

A normal code block will generate the source enclosed in `void main() {}`.
UFCS will not work because the function definition is not a global function.

__this code doesn't work__

```d disabled
auto sum(R)(R range)
{
    import std.range : ElementType;

    alias E = ElementType!R;
    auto result = E(0);
    foreach (x; range)
    {
        result += x;
    }
    return result;
}

auto arr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
auto result = arr.sum();
```

It works by setting the global attribute and writing the main function appropriately.

__this code works__

```d global
auto sum(R)(R range)
{
    import std.range : ElementType;

    alias E = ElementType!R;
    auto result = E(0);
    foreach (x; range)
    {
        result += x;
    }
    return result;
}

void main()
{
    auto arr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    auto result = arr.sum();
}
```
