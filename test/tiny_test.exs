defmodule TinyTest do
  use ExUnit.Case
  doctest Tiny

  test "array parsing" do
    error("[")
    error("[,")
    error("[1,")
    error("]")
    verify("[]", [])
    verify("[1,2,3]", [1, 2, 3])
    verify(~s(["foo","bar","baz"]), [ "foo", "bar", "baz" ])
    verify(~s([{"foo":"bar"}]), [%{ "foo" => "bar" }])
  end

  test "constant parsing" do
    verify("true", true)
    verify("false", false)
    verify("null", nil)
  end

  test "object parsing" do
    error("{")
    error("{,")
    error("}")
    error(~s({"foo"}))
    error(~s({"foo": "bar",}))
    verify("{}", %{})
    verify(~s({"foo":"bar"}), %{ "foo" => "bar" })
    verify(~s({"foo":"bar","baz":"quux"}), %{
      "foo" => "bar",
      "baz" => "quux"
    })
    verify(~s({"foo":{"bar":"baz"}}), %{
      "foo" => %{ "bar" => "baz" }
    })
  end

  test "numeric parsing" do
    error("-")
    error("--1")
    error("01")
    error(".1")
    error("1.")
    error("1e")
    error("1.0e+")
    verify("0", 0)
    verify("1", 1)
    verify("-0", 0, "0")
    verify("-1", -1)
    verify("0.1", 0.1)
    verify("-0.1", -0.1)
    verify("0e0", 0, "0")
    verify("0E0", 0, "0")
    verify("1e0", 1, "1")
    verify("1E0", 1, "1")
    verify("1.0e0", 1.0, "1.0")
    verify("1e+0", 1, "1")
    verify("1.0e+0", 1.0, "1.0")
    verify("0.1e1", 0.1e1, "1.0")
    verify("0.1e-1", 0.1e-1, "0.01")
    verify("99.99e99", 99.99e99, "9.999e100")
    verify("-99.99e-99", -99.99e-99, "-9.999e-98")
    verify("123456789.123456789e123", 123456789.123456789e123, "1.234567891234568e131")
  end

  test "string parsing" do
    error(~s("))
    error(~s("\\"))
    error(~s("\\k"))
    error(<< 34, 128, 34 >>)
    error(~s("\\u2603\\"))
    error(~s("Here's a snowman for you: ☃. Good day!))
    error(~s("𝄞))
    verify(~s("\\"\\\\\\/\\b\\f\\n\\r\\t"), "\"\\/\b\f\n\r\t", "\"\\\"\\\\/\\b\\f\\n\\r\\t\"")
    verify(~s("\\u2603"), "☃")
    verify(~s("\\u2028\\u2029"), "\u2028\u2029")
    verify(~s("\\uD834\\uDD1E"), "𝄞")
    verify(~s("\\uD834\\uDD1E"), "𝄞")
    verify(~s("\\uD799\\uD799"), "힙힙")
    verify(~s("✔︎"), "✔︎", "\"\\u2714\\uFE0E\"")
  end

  test "whitespace parsing" do
    verify(" [ 1, 2, 3 ] ", [ 1, 2, 3 ], "[1,2,3]")
    verify("[ 1 \n ]", [ 1 ], "[1]")
    verify("[ 1,\n\n\r\t2 ]", [ 1, 2 ], "[1,2]")
    verify(~s( { "foo": "bar" } ), %{ "foo" => "bar" }, ~s({"foo":"bar"}))
    verify(~s({\t"foo":\n"bar"\r}), %{ "foo" => "bar" }, ~s({"foo":"bar"}))
  end

  defp error(input) do
    assert_raise(ArgumentError, fn ->
      Tiny.decode!(input)
    end)
  end

  defp verify(input, output),
    do: verify(input, output, input)
  defp verify(input, output, encoded) do
    result1 = Tiny.decode!(input)
    result2 = Tiny.encode!(result1)
    result3 = Tiny.decode!(result2)

    assert(result1 == output)
    assert(result2 == encoded)
    assert(result3 == result1)
  end

end
