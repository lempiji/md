__command__

```
dub run -- examples/test-filter.md --filter test1
```

__test code__

```d name=test1
import std; writeln("test1");
```

```d name=test2
throw new Exception("test2");
```
