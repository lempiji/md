__command__

```
dub run -- examples/test-build.md
dub run -- examples/test-build.md --build=debug
dub run -- examples/test-build.md --build=release
```

__test code__

```d
import std.stdio;

debug {
    writeln("Debug");
}
writeln("Always");
```