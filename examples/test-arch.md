__command__

```
dub run -- examples/test-arch.md
dub run -- examples/test-arch.md --arch=x86
dub run -- examples/test-arch.md --arch=x86_64
```

__test code__

```d
import std.stdio;

version (X86) {
    writeln("X86");
}
else version (X86_64) {
    writeln("X86_64");
}
else {
    writeln("Other");
}
```