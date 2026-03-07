__command__

```
dub run -- examples/test-shell-errors.md --filter sh_unset
dub run -- examples/test-shell-errors.md --filter bash_pipefail
```

__test code__

```sh name=sh_unset
echo "${UNSET_SH_VAR}"
```

```bash name=bash_pipefail
printf 'ok\n' | grep 'ng'
echo "must-not-print"
```

### expected result

- `sh_unset` fails because `sh -u` rejects an unset variable.
- `bash_pipefail` fails because the pipeline returns non-zero under `pipefail`.
- `must-not-print` is never printed.
