# Final methodology package v2 — SHA256SUMS self-check fix

## Correction

The previous final freeze generated a valid package, but the integrity manifest included `SHA256SUMS` in its own checksum list. This creates a self-referential mismatch:

```text
./SHA256SUMS: FAILED
```

All other files were valid. The issue was limited to the checksum manifest policy.

## New behavior

`27-freeze-methodology-package.sh` now generates checksums with:

```bash
find . -type f ! -name 'SHA256SUMS' -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
```

It also validates the manifest immediately before compressing the final package.

## Validation command

After generating the package:

```bash
cd baseline/final_methodology_package_YYYYMMDDTHHMMSS
sha256sum -c SHA256SUMS
cd -
```

Expected result: no `FAILED` entries.
