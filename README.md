# rcaap-anubis-theme
Anubis RCAAP theme

## Build

Builds upstream Anubis (tag set by `ANUBIS_VERSION`) with the files in `overlay/` replacing the upstream template and mascot images:

```shell
docker build -t <user>/anubis-rcaap:1.28.1 .
```
