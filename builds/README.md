A collection of scritps and dockerfiles to build smallest-possible container images utilizing the [builder pattern](https://www.google.co.jp/search?q=docker+image+builder+pattern).
Runtime images doesn't contain C source/header files and unnecessary object files, unnecessary bundled binaries, tests and testdata included in library deps, and so on.

- alpine-rails: intended to run a rails app on Alpine Linux.
