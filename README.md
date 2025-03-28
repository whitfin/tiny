# Tiny
[![Build Status](https://img.shields.io/github/actions/workflow/status/whitfin/tiny/ci.yml?branch=main)](https://github.com/whitfin/tiny/actions) [![Hex.pm Version](https://img.shields.io/hexpm/v/tiny.svg)](https://hex.pm/packages/tiny) [![Documentation](https://img.shields.io/badge/docs-latest-blue.svg)](https://hexdocs.pm/tiny/)

Tiny is a JSON parser for Elixir written using efficient function head matches where possible.

_Update 2025: This project is quite redundant due to the inclusion of the [json](https://www.erlang.org/doc/apps/stdlib/json.html) module inside OTP. I have left this repository here primarily as an example, but also because it was fun to work on :)._

## Benefits

This library was created due to my need for a JSON parser I could easily bundle into archive builds - thus it's a single file, and very small. If you are looking for the most efficient parser (i.e. for a web service), you should probably look elsewhere -- [Jason](https://github.com/michalmuskala/jason) and [Poison](https://github.com/devinus/poison) are good options.

Why you should use Tiny:

- Allows only binary keys on decode, by design
- Allows both binary and atom keys on encode, by design
- Allows encoding to either binary or iodata
- Conforms to the standard of `(en|de)code!?`, so it can be used with Plug
- Conforms to the standard of accepting the last value set to a key in a Map
- Conforms to 100% of the spec per [JSONTestSuite](https://github.com/nst/JSONTestSuite)
- Extremely small and easy to embed

Why you should not use Tiny:

- You want to decode JSON into Maps with atom keys
- You want to decode JSON into module structs
- You want to encode JSON into anything but unicode (although you could convert yourself)
- You want hints as to why your JSON could not be parsed
- You want the fastest JSON handling; there are many better options in this case.

Realistically, most people will likely opt for one of the other parsers available. This project is largely here for the niche of bundling without Mix, and also just for example purposes.

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

## Testing and Validation

I have opted to use [JSONTestSuite](https://github.com/nst/JSONTestSuite) to test Tiny, as it is extremely extensive - particularly in terms of negative tests. Tiny passes every `y_*` and `n_*` test based on the official JSON specification.

Several of the implementation specific tests (`i_*`) fail due to the nature of Elixir (invalid floats, codepoints, etc) - but don't worry, these tests are outside the official spec which means you're probably not dealing with JSON like that anyway. There are also several tests inside this repo to cover the basic use cases - they're not super thorough, but should cover everything enough to have a valid CI build.
