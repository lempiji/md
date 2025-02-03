__command__

```
dub run -- examples/filter_example.md --filter test1 --filter test2
```

__test code__

```d name=test1
import std; writeln("test1");
```

```d name=test2
import std; writeln("test2");
```

```d name=test3
throw new Exception("test3");
```