__command__

```
dub run -- examples/test-golem.md -d golem
```

__test code__

```d global
import std.stdio;
import golem;

void main()
{
    auto x = tensor!([2, 2])([1.0f, 2.0f, 3.0f, 4.0f]);
    writeln(x.value);
}
```
