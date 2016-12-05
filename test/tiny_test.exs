defmodule TinyTest.Macro do
  import ExUnit.Assertions

  defmacro test_error(title, input) do
    quote do
      test unquote(title) <> " " <> unquote(input) do
        do_test_error(unquote(input))
      end
    end
  end

  defmacro test_verify(title, input, output),
    do: quote do: test_verify(unquote(title), unquote(input), unquote(output), unquote(input))

  defmacro test_verify(title, input, output, encoded) do
    quote do
      test unquote(title) <> " " <> unquote(input) do
        do_test_verify(unquote(input), unquote(output), unquote(encoded))
      end
    end
  end

  def do_test_error(input) do
    assert_raise(ArgumentError, fn ->
      Tiny.decode!(input)
    end)
  end

  def do_test_verify(input, output, encoded) do
    result1 = Tiny.decode!(input)
    result2 = Tiny.encode!(result1)
    result3 = Tiny.decode!(result2)

    assert(result1 === output)
    assert(result2 == encoded)
    assert(result3 == result1)
  end

end

defmodule TinyTest do
  use ExUnit.Case
  import TinyTest.Macro
  doctest Tiny

  # arrays
  test_error("array parsing",  "[")
  test_error("array parsing",  "[,")
  test_error("array parsing",  "[1,")
  test_error("array parsing",  "]")
  test_error("array parsing",  "[1, 2, 3,]")
  test_verify("array parsing", "[]", [])
  test_verify("array parsing", "[1,2,3]", [1, 2, 3])
  test_verify("array parsing", "[{}]", [%{}])
  test_verify("array parsing", ~s(["foo","bar","baz"]), [ "foo", "bar", "baz" ])
  test_verify("array parsing", ~s([{"foo":"bar"}]), [%{ "foo" => "bar" }])
  test_verify("array parsing",
    "[1, 2, [3, [4, 5]], 6, [true, false], [null], [[]]]",
     [1, 2, [3, [4, 5]], 6, [true, false], [nil],  [[]]],
    "[1,2,[3,[4,5]],6,[true,false],[null],[[]]]")
  test_verify("array parsing",
    "[1e2, true, false, null, {\"a\": [\"hello\"], \"b\": [\"world\"]}, [1e-2]]",
     [100.0, true, false, nil, %{"a" => [ "hello" ], "b" => [ "world" ]}, [0.01]],
     ~s([100.0,true,false,null,{"b":["world"],"a":["hello"]},[0.01]]))

  # constants
  test_verify("constants parsing", "true", true)
  test_verify("constants parsing", "false", false)
  test_verify("constants parsing", "null", nil)

  # objects
  test_error("object parsing",  "{")
  test_error("object parsing",  "{,")
  test_error("object parsing",  "}")
  test_error("object parsing",  ~s({"foo"}))
  test_error("object parsing",  ~s({"foo": "bar",}))
  test_error("object parsing",  "{key: 1}")
  test_error("object parsing",  "{false: 1}")
  test_error("object parsing",  "{true: 1}")
  test_error("object parsing",  "{null: 1}")
  test_error("object parsing",  "{'key': 1}")
  test_error("object parsing",  "{1: 2, 3: 4}")
  test_error("object parsing",  "{\"hello\": \"world\", \"foo\": \"bar\",}")
  test_verify("object parsing", "{}", %{})
  test_verify("object parsing", ~s({"foo":"bar"}), %{ "foo" => "bar" })
  test_verify("object parsing", ~s({"foo":"bar","baz":"quux"}), %{
    "foo" => "bar",
    "baz" => "quux"
  })
  test_verify("object parsing", ~s({"foo":{"bar":"baz"}}), %{
    "foo" => %{ "bar" => "baz" }
  })
  test_verify("object parsing", ~s({"hello":"world","fox":{"quick":true,"purple":false},"foo":["bar",true]}), %{
    "hello" => "world",
    "foo" => ["bar", true],
    "fox" => %{
      "quick" => true,
      "purple" => false
    }
  })

  # numerics
  test "numeric parsing octals" do
    octals = [
      "00", "01", "02", "03",
      "04", "05", "06", "07",
      "010", "011", "08", "018"
    ]

    for octal <- octals do
      do_test_error(octal)
      do_test_error("-" <> octal)
      do_test_error(~s("\\) <> octal <> ~s("))
      do_test_error(~s("\\x) <> octal <> ~s("))
    end
  end
  test_error("numeric parsing",  "-")
  test_error("numeric parsing",  "--1")
  test_error("numeric parsing",  "001")
  test_error("numeric parsing",  ".1")
  test_error("numeric parsing",  "1.")
  test_error("numeric parsing",  "1e")
  test_error("numeric parsing",  "1.0e+")
  test_error("numeric parsing",  "+1")
  test_error("numeric parsing",  "1-+")
  test_error("numeric parsing",  "0xaf")
  test_error("numeric parsing",  "- 5")
  test_verify("numeric parsing", "0", 0)
  test_verify("numeric parsing", "1", 1)
  test_verify("numeric parsing", "-0", 0, "0")
  test_verify("numeric parsing", "-1", -1)
  test_verify("numeric parsing", "100", 100)
  test_verify("numeric parsing", "-100", -100)
  test_verify("numeric parsing", "0.1", 0.1)
  test_verify("numeric parsing", "-0.1", -0.1)
  test_verify("numeric parsing", "10.5", 10.5)
  test_verify("numeric parsing", "0.625", 0.625)
  test_verify("numeric parsing", "-3.141", -3.141)
  test_verify("numeric parsing", "-0.03125", -0.03125)
  test_verify("numeric parsing", "0e0", 0.0, "0.0")
  test_verify("numeric parsing", "0E0", 0.0, "0.0")
  test_verify("numeric parsing", "1e0", 1.0, "1.0")
  test_verify("numeric parsing", "1E0", 1.0, "1.0")
  test_verify("numeric parsing", "1E2", 100.0, "100.0")
  test_verify("numeric parsing", "1.0e0", 1.0, "1.0")
  test_verify("numeric parsing", "1e+0", 1.0, "1.0")
  test_verify("numeric parsing", "1.0e+0", 1.0, "1.0")
  test_verify("numeric parsing", "1e3", 1000.0, "1.0e3")
  test_verify("numeric parsing", "1e+2", 100.0, "100.0")
  test_verify("numeric parsing", "-1e-2", -0.01, "-0.01")
  test_verify("numeric parsing", "0.1e1", 0.1e1, "1.0")
  test_verify("numeric parsing", "0.1e-1", 0.1e-1, "0.01")
  test_verify("numeric parsing", "0.03125e+5", 3125.0, "3125.0")
  test_verify("numeric parsing", "99.99e99", 99.99e99, "9.999e100")
  test_verify("numeric parsing", "-99.99e-99", -99.99e-99, "-9.999e-98")
  test_verify("numeric parsing", "123456789.123456789e123", 123456789.123456789e123, "1.234567891234568e131")

  # strings
  test "unescaped control characters" do
    ctrl_chars = [
      "\u0001", "\u0002", "\u0003", "\u0004", "\u0005", "\u0006", "\u0007",
      "\b", "\t", "\n", "\u000b", "\f", "\r", "\u000e", "\u000f", "\u0010",
      "\u0011", "\u0012", "\u0013", "\u0014", "\u0015", "\u0016", "\u0017",
      "\u0018", "\u0019", "\u001a", "\u001b", "\u001c", "\u001d", "\u001e",
      "\u001f"
    ]

    for ctrl_char <- ctrl_chars do
      do_test_error(~s(#{ctrl_char}))
    end
  end
  test_error("string parsing", ~s("))
  test_error("string parsing", ~s("\\"))
  test_error("string parsing", ~s("\\k"))
  test_error("string parsing", ~s("\\u2603\\"))
  test_error("string parsing", ~s('hello'))
  test_error("string parsing", ~s(\\x61))
  test "string parsing non-utf8 values", do: do_test_error(<< 34, 128, 34 >>)
  test "string parsing unescaped \\u2603", do: do_test_error(~s("Here's a snowman for you: ☃. Good day!))
  test "string parsing unescaped \\uD834\\uDD1E", do: do_test_error(~s("𝄞))
  test_verify("string parsing", ~s("value"), "value")
  test_verify("string parsing", ~s(""), "")
  test_verify("string parsing", ~s("\\u0001"), "\u0001")
  test_verify("string parsing", ~s("hello\\/world"), "hello/world", ~s("hello/world"))
  test_verify("string parsing", ~s("hello\\\\world"), "hello\\world")
  test_verify("string parsing", ~s("hello\\"world"), "hello\"world")
  test_verify("string parsing", ~s("\\"\\\\\\/\\b\\f\\n\\r\\t"), "\"\\/\b\f\n\r\t", "\"\\\"\\\\/\\b\\f\\n\\r\\t\"")
  test_verify("string parsing", ~s("\\u2603"), "☃")
  test_verify("string parsing", ~s("\\u2028\\u2029"), "\u2028\u2029")
  test_verify("string parsing", ~s("\\ud834\\udd1e"), "𝄞", ~s("\\uD834\\uDD1E"))
  test_verify("string parsing", ~s("\\uD834\\uDD1E"), "𝄞")
  test_verify("string parsing", ~s("\\uD799\\uD799"), "힙힙")
  test "string parsing  \\u2714\\uFE0E", do: do_test_verify(~s("✔︎"), "✔︎", "\"\\u2714\\uFE0E\"")

  # whitespace
  test "invalid characters" do
    characters = [
      "{\u00a0}", "{\u1680}", "{\u180e}", "{\u2000}", "{\u2001}", "{\u2002}",
      "{\u2003}", "{\u2004}", "{\u2005}", "{\u2006}", "{\u2007}", "{\u2008}",
      "{\u2009}", "{\u200a}", "{\u202f}", "{\u205f}", "{\u3000}", "{\u2028}",
      "{\u2029}"
    ]

    for char <- characters do
      do_test_error(char)
    end

    do_test_error("{\u000b}")
    do_test_error("{\u000c}")
    do_test_error("{\ufeff}")
  end
  test_verify("whitespace parsing", "{\r\n}", %{}, "{}")
  test_verify("whitespace parsing", "{\n\n\r\n}", %{}, "{}")
  test_verify("whitespace parsing", "{\t}", %{}, "{}")
  test_verify("whitespace parsing", "{  }", %{}, "{}")
  test_verify("whitespace parsing", " [ 1, 2, 3 ] ", [ 1, 2, 3 ], "[1,2,3]")
  test_verify("whitespace parsing", "[ 1 \n ]", [ 1 ], "[1]")
  test_verify("whitespace parsing", "[ 1,\n\n\r\t2 ]", [ 1, 2 ], "[1,2]")
  test_verify("whitespace parsing", ~s( { "foo": "bar" } ), %{ "foo" => "bar" }, ~s({"foo":"bar"}))
  test_verify("whitespace parsing", ~s({\t"foo":\n"bar"\r}), %{ "foo" => "bar" }, ~s({"foo":"bar"}))

end
