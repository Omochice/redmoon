# omochice/mcp

A dual-era MCP tool server over stdio, written for redmoon and usable by any MoonBit program that offers tools.
[ADR-004](../doc/adr/adr-004-mcp-sdk-scope.md) records why the module exists and why it covers only what is listed below.

## What is supported

A client can rely on the following, whichever era it speaks.

- Legacy clients that open with `initialize`, at protocol versions `2025-11-25`, `2025-06-18`, `2025-03-26`, and `2024-11-05`.
- Modern clients that name `2026-07-28` in `params._meta` of every request, answered with `resultType` and `server/discover`.
- `tools/list` and `tools/call`, with the arguments of each tool validated against an `omochice/schema` definition before the handler runs.
- `ping`, `notifications/initialized`, and `notifications/cancelled`, which stops the task of the cancelled request.
- One task per request on `moonbitlang/async`, serialized writes to stdout, and a graceful end when stdin closes.

## What is not supported

The gaps below are the ones ADR-004 accepted with the decision.

- Resources, prompts, progress, logging, subscriptions, and multi round-trip requests.
- `structuredContent`; a tool result carries text content only.
- The HTTP transport; `serve` takes any `@io.Reader` and `@io.Writer`, but only stdio is wired up.

## Usage

The program below is `src/example/main.mbt` and registers one tool that echoes its argument.

```moonbit
async fn main {
  let text = @schema.required("text", @schema.string())
  let echo = @mcp.tool(
    name="echo",
    description="Returns the given text",
    input=@schema.record([text.as_member()], v => v.get(text)),
    handler=fn(text) { @mcp.ToolResult::text(text) },
  )
  @mcp.Server::new(name="mcp-example", version="0.1.0", tools=[echo]).serve_stdio()
}
```

`Server::new` also takes `instructions?` for the text a client shows its model, and `on_invalid?` to shape the tool result of an argument that fails validation.
A handler returns `ToolResult::text` on success and `ToolResult::error` on failure, and both reach the client as a tool result rather than a protocol error.
