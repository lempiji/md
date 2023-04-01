__command__

```
dub run -- examples/test-compiler.md
dub run -- examples/test-compiler.md --compiler=ldc2
```

__test code__

```d
import std.stdio;

version (DigitalMars) {
    writeln("DigitalMars");
}
version (GNU) {
    writeln("GNU");
}
version (LDC) {
    writeln("LDC");
}
```