# Errors And External Commands

Failures are part of a command's contract; model them as typed errors the caller
can handle, attach context as they propagate, and never swallow them or crash on
a recoverable condition.

## External Commands Fail Fast

Run external commands with the `^` prefix. A non-zero exit aborts the script by
default:

```nu
print "before"
^false              # script stops here with a non-zero exit code
print "after"       # never runs
```

This fail-fast default is what we want for orchestration. Make exceptions
explicit (next sections) rather than disabling the behavior.

## Capture A Failure With `complete`

When a command is _expected_ to sometimes fail (probing, retries), wrap it in
`do { ... } | complete` to get a record `{ stdout, stderr, exit_code }` instead
of aborting:

```nu
let r = (do { ^ssh-keyscan -q -t ed25519 $ip } | complete)
if $r.exit_code != 0 {
    log warning $"ssh-keyscan failed: ($r.stderr | str trim)"
    # decide what to do; do NOT silently continue as if it succeeded
}
let key = ($r.stdout | str trim)
```

## Catch With `try/catch`

```nu
try {
    ^just openstack::close-ssh $deploy_id
} catch {|err|
    log warning $"Best-effort cleanup failed: ($err.msg)"
}
```

The catch closure receives an error record (`$err.msg`, and `$err.debug` for the
full value). Use this for best-effort cleanup or to add context before
re-raising.

## Raise A Typed Error

`error make` raises a structured, catchable error and halts the current command;
it returns control to the caller rather than killing the process abruptly.

```nu
def "main get-ip" [comp: string] {
    let f = $"components/($comp)/deploy.yaml"
    if not ($f | path exists) {
        error make {msg: $"Component '($comp)' has no deploy.yaml."}
    }
    open $f | get ip.public
}
```

For argument-level errors, attach a span so the message underlines the offending
argument:

```nu
def "main set-index" [idx: int] {
    if $idx < 0 {
        error make {
            msg: "index must be non-negative"
            label: {text: "negative here", span: (metadata $idx).span}
        }
    }
}
```

For a plain fatal message, pass only `msg`; for multiple lines, build the string
with interpolation. Avoid wrapper helpers like a bash-style `die` — `error make`
is the idiom, and a wrapper that sets `--unspanned` only throws away the source
location nushell would otherwise show.

```nu
error make {msg: "Could not get tofu output.\nIs the component deployed?"}
```

## Propagate With Context

When a lower-level call fails, add what was being attempted before surfacing it,
so the root cause stays recoverable from the trace:

```nu
let out = (try { ^just tofu output $comp } catch {
    error make {msg: $"Could not read tofu output for ($comp)."}
})
```

## Retry Pattern

Replaces the bash `while [ $count -le $max ]` loop. Bounded, typed, no silent
swallow:

```nu
def fetch-age-key [ip: string, --max: int = 200]: nothing -> string {
    for attempt in 1..$max {
        let r = (do { ^ssh-keyscan -q -t ed25519 $ip } | complete)
        if $r.exit_code == 0 and ($r.stdout | str trim | is-not-empty) {
            return ($r.stdout | str trim | ^ssh-to-age | str trim)
        }
        log info $"ssh-keyscan retry ($attempt)/($max)"
        sleep 1sec
    }
    error make {msg: $"Could not ssh-keyscan ($ip) after ($max) attempts."}
}
```

## Cleanup Without `trap`

Nushell has no `trap`; wrap the risky section so cleanup always runs. Raise a
_contextual_ message — do not rewrap `$err.msg`, which for a failed external is
only the generic "non-zero exit code" (the command's own stderr has already
streamed to the terminal):

```nu
^just openstack::open-ssh $deploy_id
try {
    ^just bootstrap-nixos $comp $ip
} catch {
    ^just openstack::close-ssh $deploy_id
    error make {msg: $"bootstrap-nixos failed for ($comp); see output above."}
}
^just openstack::close-ssh $deploy_id
```

When you need the failure _details_ in the message (at the cost of live output),
capture with `complete`, clean up unconditionally, then raise:

```nu
^just openstack::open-ssh $deploy_id
let r = (do { ^just bootstrap-nixos $comp $ip } | complete)
^just openstack::close-ssh $deploy_id          # always runs
if $r.exit_code != 0 {
    error make {msg: $"bootstrap-nixos failed: ($r.stderr | str trim)"}
}
```

## Passing Arguments To Externals

```nu
let extra = [-o StrictHostKeyChecking=accept-new]
^ssh ...$extra $"root@($ip)" reboot
```

Spread (`...$list`) expands a list into separate argv entries. Build argv as a
list and spread it, rather than assembling a single string.
