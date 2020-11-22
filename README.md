# Tiny

Tiny is a JSON parser for Elixir written using efficient function head matches where possible. I wrote it due to my need for a JSON parser which could bundle easily into archive builds without having to go through and rename module references - thus it's a single file, and very small. Upon benching it, I found it was actually pretty fast and so decided to bundle it up and make it available as a package. It is intentionally "basic" as to what it can do, to avoid bloat (if you want extras, go use the excellent [Poison](https://github.com/devinus/poison)).

Why you should use Tiny:

- Allows only binary keys on decode, by design
- Allows both binary and atom keys on encode, by design
- Allows encoding to either binary or iodata
- Conforms to the standard of `(en|de)code!?`, so it can be used with Plug
- Conforms to the standard of accepting the last value set to a key in a Map
- Conforms to 100% of the spec per [JSONTestSuite](https://github.com/nst/JSONTestSuite) (the only Elixir parser to do so)
- Extremely fast; initial benchmarks show speed comparable to Poison (with slight gains in some areas)
- Extremely small; initial implementation only 152 SLOC (w/o docs)

Why you should not use Tiny:

- You want to decode JSON into Maps with atom keys
- You want to decode JSON into module structs
- You want to encode JSON into anything but unicode (although you could convert yourself)
- You want hints as to why your JSON could not be parsed

## Installation

Tiny is on Hex, and you can install it using the usual:

  1. Add `tiny` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:tiny, "~> 1.0"}]
end
```

  2. Ensure `tiny` is started before your application:

```elixir
def application do
  [applications: [:tiny]]
end
```

## Usage

As mentioned, usage is intentionally super simple (this is the entire interface):

```elixir
# test input for decode
iex(1)> input = "{\"key\":\"value\"}"
"{\"key\":\"value\"}"
# "safe" decoding
iex(2)> { :ok, terms } = Tiny.decode(input)
{:ok, %{"key" => "value"}}
# "unsafe" decoding (raises ArgumentError)
iex(3)> terms = Tiny.decode!(input)
%{"key" => "value"}
# "safe" encoding
iex(4)> { :ok, json } = Tiny.encode(terms)
{:ok, "{\"key\":\"value\"}"}
# "unsafe" encoding (raises ArgumentError)
iex(5)> json = Tiny.encode!(terms)        
"{\"key\":\"value\"}"
```

If your input is invalid, you'll receive an `ArgumentError`. If you're running your code in production, it's a waste of time to give you the character causing the error seeing you don't know the JSON you just tried to parse. If you do have it to hand (from your logs or something), you can just drop it in a JSON linter and it'll show you where the error is - there's no need to incur the overhead on every successful parse request. If you don't find this desirable, you should use Poison instead as it does keep track of the column/character where errors occur.

All of the functions shown above do accept a second optional argument containing a `Keyword` list of options. At the moment, the only option supported is `:iodata` in the `encode` functions, which will output your encoded JSON as `iodata` rather than a binary if truthy (please note "truthy" and not `true`). This flag is the same as the current (3.x) Poison option, for convenience.

## Testing and Benchmarking

I have opted to use [JSONTestSuite](https://github.com/nst/JSONTestSuite) to test Tiny, as it is extremely extensive - particularly in terms of negative tests. Tiny passes every `y_*` and `n_*` test based on the official JSON specification (and is the only Elixir project I know of which does currently). Several of the implementation specific tests (`i_*`) fail due to the nature of Elixir (invalid floats, codepoints, etc) - but don't worry, these tests are outside the official spec which means you're probably not dealing with JSON like that anyway. There are also several tests inside this repo to cover the basic use cases - they're not super thorough, but should cover everything enough to have a valid CI build.

There are some basic benchmarks in `bench/` which can be run using `mix bench` in the command line. These benchmarks should give a reasonable view into how fast Tiny is compared to some other JSON libraries. Additions/modifications are welcomed here, as there are only basic cases covered for now. Feel free to add missing JSON libraries, too!
