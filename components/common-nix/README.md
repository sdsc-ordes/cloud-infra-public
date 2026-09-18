# Component `common-nix`

This component contains all shared nix modules, overlays and packages that may
be reused across components. It is a code sharing module that cannot be deployed
in itself.

## Conventions

Create directories as needed in `.` (e.g. `overlays`). Try to
[KISS](https://en.wikipedia.org/wiki/KISS_principle) whenever possible, with
plain NixOs modules without frameworks.
