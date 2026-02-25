__command__

```
dub run -- examples/test-multiple-name.md
dub run -- examples/test-multiple-name.md --filter=test1
dub run -- examples/test-multiple-name.md --filter=test2
```

__test code__

```d name=test1 name=test2
import std.stdio;
```

```d name=test1
writeln("test1");
```

```d name=test2
writeln("test2");
```

###  expected output

no filter:

__test1__
```
test1
```
__test2__
```
test2
```

filter test1:

__test1__
```
test1
```

filter test2:

__test2__
```
test2
```