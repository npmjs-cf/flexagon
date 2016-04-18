# Flexagon

Flexagon is an npm registry proxy, written in Elixir, to route between scope and
unscoped registry instances. JSON responses are rewritten to ensure tarballs are
fetched from this proxy. The package tarballs are streamed from the upstream
server to the end user.

Flexagon is used by the [npmjs.cf][npmjs-cf] service to deliver public scoped
modules from the [npm, Inc.][npmjs] registry.

## Running

Install the dependencies with `mix deps.get`, then run with `mix run --no-halt`.

Future versions may be distributed on hex or generated with the Elixir Release
Manager. Help definitely wanted. :heart_eyes:

## Disclaimer

“npm” is a trademark of npm, Inc., and is not affiliated with npmjs.cf or
the Flexagon project.

[npmjs-cf]: https://www.npmjs.cf
[npmjs]: https://www.npmjs.com
