# Token Efficiency & Research Protocol

To maintain high performance and context clarity, follow these rules when using this skill:

## 1. Targeted Research (Grep First)
Before reading entire files, identify relevant code patterns:
- API Handlers: `grep "fn.*(req:.*Request)"`
- JSON Decoders: `grep "decode.field"`
- SQL Queries: `grep -r "sql\."`
- Lustre Messages: `grep "type Msg"`

## 2. Surgical Reads
- Use `read_file` with `start_line` and `end_line` for large controller files.
- Always read the `shared/src/shared/<domain>.gleam` file first to understand the data contract.

## 3. Skill Activation Rule
If you are working on a feature, you **MUST** read the corresponding reference in `references/` before opening the implementation file. 
**Example**: "I am about to implement a new GET route. I am reading `references/route-naming.md` and `references/query-dispatch.md` to ensure compliance."

## 4. Documentation Lookup
If unsure about a package version or API:
1. Check `gleam.toml` of the specific package (`client` or `server`).
2. Check `/home/svarona/Development/lustre/examples/` for usage.
3. Only then, ask the user or propose a solution.
