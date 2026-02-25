__command__

```
dub run -- examples/test-shell.md
dub run -- examples/test-shell.md --filter sh_test
dub run -- examples/test-shell.md --filter bash_test
```

__test code__

```sh name=sh_test name=bash_test
shared_sh="multi-name"
```

```sh name=sh_test
echo "sh:${shared_sh}"
```

```bash name=sh_test name=bash_test
shared_bash="multi-name"
```

```bash name=bash_test
parts=("A" "B")
echo "bash:${shared_bash}:${parts[1]}"
```

### expected output

no filter:

```
sh:multi-name
bash:multi-name:B
```

filter sh_test:

```
sh:multi-name
```

filter bash_test:

```
bash:multi-name:B
```
