__command__

```
dub run -- examples/test-shell-buildonly.md --buildOnly
```

__test code__

```sh name=build_only
echo "shell buildOnly should not run"
touch build-only-should-not-exist
```

### expected result

- `--buildOnly` returns success.
- `build-only-should-not-exist` is not created.
