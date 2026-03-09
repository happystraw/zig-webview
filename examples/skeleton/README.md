# skeleton

A minimal webview app template with a Zig backend and a TypeScript frontend bundled by [Bun](https://bun.sh).

Requires Bun 1.3.10 or later (`--compile --target=browser` for self-contained HTML output).

## Structure

```
src/
  main.zig        # Zig entry point; defines webview bindings
  view/
    app.css       # Frontend styles
    app.html      # Frontend entry point
    app.ts        # Frontend logic
    bindings.d.ts # TypeScript types for webview bindings
```

## Build & Run

```sh
zig build run
```

The Zig build system automatically runs `bun run build` in `src/view/` before compiling.
