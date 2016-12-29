defmodule Tiny do
  @moduledoc """
  This module contains the entirely of the Tiny project. There are interface
  functions for encoding and decoding JSON, and little else.

  Both encoding and decoding are done per the JSON specification with direct
  mapping between JSON types and Elixir types:

   --------------------------------
  | JSON Type |     Elixir Type    |
  |:---------:|:------------------:|
  |   Array   |        List        |
  |  Boolean  |  `true` or `false` |
  |   Object  |        Map         |
  |   Number  |  Integer or Float  |
  |   String  |       Binary       |
  |   `null`  |       `nil`        |
   --------------------------------

  Numbers are parsed into Integer types when possible, falling back to Floats
  when required. This is due to functions which operate differently based on
  the numeric typing.
  """
  use Bitwise

  ############
  # Constants
  ############

  @type json :: atom | binary | list | map | number

  ############
  # Encoding
  ############

  @doc """
  Safely encodes a JSON compatible value to iodata or a binary.

  Parsing errors are caught and an `:error` Tuple is returned. Any successful
  values are wrapped in an `:ok` Tuple.
  """
  @spec encode(json, Keyword.t) ::
    { :ok, binary | iodata } |
    { :error, atom }
  def encode(val, opts \\ []),
    do: wrap(&encode!/2, val, opts)

  @doc """
  Encodes a JSON compatible value to iodata or a binary.

  Rather than return Tuples, this function will raise `ArgumentError` on invalid
  inputs. No information is provided beyond the error, so log context as needed.
  """
  @spec encode!(json, Keyword.t) :: binary | iodata | no_return
  def encode!(val, opts \\ []) do
    result = do_encode(val)
    opts[:iodata] && result || :erlang.iolist_to_binary(result)
  rescue _ -> raise ArgumentError
  end

  @doc """
  Safely encodes a value to JSON as iodata.

  Same as passing `[ iodata: true ]` to `encode/2`.
  """
  @spec encode_to_iodata(json, Keyword.t) ::
    { :ok, iodata } |
    { :error, atom }
  def encode_to_iodata(val, opts \\ []),
    do: encode(val, [ iodata: true ] ++ opts)

  @doc """
  Encodes a value to JSON as iodata.

  Same as passing `[ iodata: true ]` to `encode!/2`.
  """
  @spec encode_to_iodata!(json, Keyword.t) :: iodata | no_return
  def encode_to_iodata!(val, opts \\ []),
    do: encode!(val, [ iodata: true ] ++ opts)

  # Entry point of the main encoding path. We match on the value types before
  # handling them separately due to each being encoded differently. All calls
  # for encoding should happen via this function. We only support types which
  # have a direct equivalent in the JSON specification (e.g. no Tuples).
  defp do_encode(nil), do: "null"
  defp do_encode(val) when is_number(val) or is_boolean(val), do: to_string(val)
  defp do_encode(val) when is_binary(val) or is_atom(val),
    do: [ ?", encode_escape(coerce_key(val)), ?" ]
  defp do_encode(val) when is_list(val),
    do: [ ?[, :lists.foldl(&list_encode/2, [], val), ?] ]
  defp do_encode(val) when is_map(val),
    do: [ ?{, Enum.reduce(val, [], &pair_encode/2), ?} ]

  # Coerces an object key to a valid binary key. If the value is a binary then
  # it will return as is. If it's an Atom we convert it to a binary (skipping
  # the protocol). Anything else isn't a valid JSON key, so we just error as it's
  # not for us to decide how to convert other keys to binary - it's better for
  # the user to be explicit rather than putting the decision on Tiny.
  defp coerce_key(bin) when is_binary(bin), do: bin
  defp coerce_key(atom), do: Atom.to_string(atom)

  # Encodes a list to the binary equivalent, by just passing each value back into
  # our `do_encode/1` function. For every value other than the first, we have to
  # place a comma before the encoded value to separate the JSON correctly.
  # TODO: Is there an inefficiency here with the recursion/extra list?
  defp list_encode(val, []),  do: [ do_encode(val) ]
  defp list_encode(val, acc), do: [ acc, ?, | list_encode(val, []) ]

  # Encodes map pairs by coercing the key to a binary and encoding both the key
  # and the value using the `do_encode/1` function. Just like `list_encode/2`,
  # we only add the comma separation in the case of a non-empty set.
  # TODO: Inefficiency due to ordering?
  defp pair_encode({ key, val }, []),
    do: [ do_encode(coerce_key(key)), ?:, do_encode(val) ]
  defp pair_encode({ _key, _val } = pair, acc),
    do: [ pair_encode(pair, []), ?, | acc ]

  # Moves through the binary in blocks, by looking ahead until we find chars
  # which require escaping to avoid writing to iodata too much. We replace the
  # accepted control characters with their escaped counterparts, and convert any
  # other control characters to their `\u` form to include them in the output.
  # TODO: Is the first iteration block necessary?
  # TODO: Can we compile the padded sequences for better performance?
  defp encode_escape(""), do: []
  for { key, replace } <- List.zip([ '"\\\n\t\r\f\b', '"\\ntrfb' ]) do
    defp encode_escape(<< unquote(key), rest :: binary >>),
      do: [ unquote("\\" <> << replace >>) | encode_escape(rest) ]
  end
  defp encode_escape(<< val, rest :: binary >>) when val <= 0x1F or val == 0x7F,
    do: [ convert_sequence(val) | encode_escape(rest) ]
  defp encode_escape(<< val :: utf8, rest :: binary >>) when val > 0xFFFF do
    code = val - 0x10000
    [convert_sequence(0xD800 ||| (code >>> 10)),
     convert_sequence(0xDC00 ||| (code &&& 0x3FF)) | encode_escape(rest)]
  end
  defp encode_escape(<< val :: utf8, rest :: binary >>) when val > 0x7F,
    do: [ convert_sequence(val) | encode_escape(rest) ]
  defp encode_escape(bin) do
    valid_count = detect_string(bin, 0, &find_escaped/3)
    << value :: binary-size(valid_count), rest :: binary >> = bin
    [ value | encode_escape(rest) ]
  end

  # Locates the length of a correctly escaped binary so that we can pull it back
  # in a pattern match using a subreference to avoid writing multiple times. We
  # simply look at ranges to determine things which have been correctly escaped.
  defp find_escaped(<< _val :: utf8, _rest :: binary >>, acc, _ca),
    do: valid_count!(acc)
  defp find_escaped("", acc, _ca),
    do: valid_count!(acc)

  # Converts a character integer to a list before passing it through to have the
  # correct padding applied in order to construct a valid control sequence.
  defp convert_sequence(char), do: pad_sequence(:erlang.integer_to_list(char, 16))

  # Converts a character to it's `\u` form so that it can be safely included in
  # our JSON output (as control chars without escapes are invalid).
  defp pad_sequence(seq), do: [ "\\u", :binary.copy("0", 4 - length(seq)) | seq ]

  ############
  # Decoding
  ############

  @doc """
  Safely decodes a JSON input binary to an Elixir term.

  Parsing errors are caught and an `:error` Tuple is returned. Any successful
  values are wrapped in an `:ok` Tuple.
  """
  @spec decode(binary, Keyword.t) ::
    { :ok, json } |
    { :error, atom }
  def decode(bin, opts \\ []), do: wrap(&decode!/2, bin, opts)

  @doc """
  Decodes a JSON inout binary to an Elixir term.

  Rather than return Tuples, this function will raise `ArgumentError` on invalid
  inputs. No information is provided beyond the error, so log context as needed.
  """
  @spec decode!(binary, Keyword.t) :: json | no_return
  def decode!(bin, _opts \\ []) when is_binary(bin) do
    { rest, value } = do_decode(strip_ws(bin))
    "" = strip_ws(rest); value
  rescue _ -> raise ArgumentError
  end

  # Entry point of the main decoding path. We have to inspect the first character
  # in order to figure out what exactly we need to do next. It should be pretty
  # straightforward to see the logical separation here via the matching taking
  # place. Please note how only some use `strip_ws(rest)`, as not all characters
  # need whitespace stripping following them - important to recognise.
  defp do_decode(<< "\"",    rem :: binary >>), do: decode_string(rem, "")
  defp do_decode(<< "{",     rem :: binary >>), do: decode_object(strip_ws(rem), [])
  defp do_decode(<< "[",     rem :: binary >>), do: decode_array(strip_ws(rem), [])
  defp do_decode(<< "true",  rem :: binary >>), do: { strip_ws(rem), true }
  defp do_decode(<< "false", rem :: binary >>), do: { strip_ws(rem), false }
  defp do_decode(<< "null",  rem :: binary >>), do: { strip_ws(rem), nil }
  defp do_decode(<< val, _rest :: binary >> = bin) when val in '0123456789-',
    do: decode_number(bin)

  # Entry point for decoding an array binary. We have a match on a terminating
  # brace, as well as an empty accumulator to signal an empty list. Otherwise
  # we pass the remainder back into the decoder so that it can do the heavy
  # lifting for us, rather than parsing again. We then just pass the remainder
  # through to `enforce_array_terminator/2` and prepend the value to the acc.
  # It should be noted that the remainder coming back from `do_decode/1` will
  # have always have already had leading whitespace trimmed (I hope).
  defp decode_array(<< "]", rest :: binary >>, []), do: { strip_ws(rest), [] }
  defp decode_array(bin, acc) do
    { rest, value } = do_decode(bin)
    enforce_array_terminator(rest, [ value | acc ])
  end

  # Because the remainders passed in have had leading whitespace trimmed, the
  # only valid characters to come next are the comma and the brace terminator.
  # If we receive a comma, we remove whitespace after it and pass the remainder
  # back through to the initial array decoder. If we've hit the end of the list
  # then we just remove the leading whitespace and return the parsed list.
  defp enforce_array_terminator(<< ",", rest :: binary >>, acc),
    do: decode_array(strip_ws(rest), acc)
  defp enforce_array_terminator(<< "]", rest :: binary >>, acc),
    do: { strip_ws(rest), :lists.reverse(acc) }

  # Entry point for decoding a numeric value. Numbers are hard, so we actually
  # let `Float.parse/1` do most of it for us as we can assume the authors know
  # optimizations far better than I. Once again we make use of subreferencing
  # to count ahead so that we don't keep having to write intermediate stores.
  # Once we know our valid length, we pluck the numbder and pass it through to
  # be parsed. We then do a little bit of cleanup because `Float.parse/1` will
  # return a Float even in case of an Integer, so we round when necessary.
  defp decode_number(bin) do
    count = detect_number(bin, 0, 0)
    << number :: binary-size(count), rest :: binary >> = bin
    { strip_ws(rest), parse_numeric(Integer.parse(number), number) }
  end

  # Detects a number at the start of a binary. In the case of a leading zero, we
  # pass it through to `enforce_zero/2` to guarantee that it's correctly followed
  # by a valid character. If we hit a character which validates any following
  # zeroes, we flip the third argument to make it possible to receive zeroes in
  # future. Otherwise we just count on remaining valid characters, and return
  # the accumulated count once we hit the logical end of a numeric value.
  defp detect_number(<< "0", rest :: binary >>, acc, 0),
    do: enforce_zero(rest, acc + 1)
  defp detect_number(<< ".", rest :: binary >>, acc, _zero),
    do: detect_number(rest, acc + 1, 1)
  defp detect_number(<< val, rest :: binary >>, acc, _zero) when val in '123456789.eE',
    do: detect_number(rest, acc + 1, 1)
  defp detect_number(<< val, rest :: binary >>, acc, zero) when val in '0-+',
    do: detect_number(rest, acc + 1, zero)
  defp detect_number(_bin, acc, _zero), do: acc

  # Enforces that a zero has a correct character following it in order to parse
  # and reject as necessary. JSON dictates that `-012` is invalid but that things
  # such as `-0.12` are valid, so we need to make sure we can detect these cases.
  defp enforce_zero(<< val, rest :: binary >>, acc) when val in '.eE',
    do: detect_number(rest, acc + 1, 1)
  defp enforce_zero(<< val, _rest :: binary >>, acc) when not val in '0123456789+-',
    do: acc
  defp enforce_zero(<< >>, acc), do: acc

  # Parses a numeric value to the correct numeric type in Elixir. This suck and
  # is inefficient, but it's required to avoid having to write a number parser.
  # We try to parse as an Integer, and if that fails (i.e. in case of decimal or
  # exponent), then we try to parse as a Float. Neither allow trailing characters.
  defp parse_numeric({ num, "" }, _val), do: num
  defp parse_numeric(_error, val) do
    { num, "" } = Float.parse(val)
      num
  end

  # Entry point for parsing object values. This makes heavy use of other functions
  # in order to avoid re-inventing the wheel. If the remainder has a leading `"`
  # then we are working with a key, so we pass it through to the string decoder
  # in order to spit us back a new remainder and a key. This remainder *must*
  # have a comma as the first character, so we ignore that and store the rest.
  # We then strip the whitespace after the comma and pass it through to then be
  # decoded as a value (using any decoder). Assuming success, we then pass the
  # rest through to `enforce_object_terminator/2` to continue parsing the pairs.
  # Note that we use a list for storage until termination, as it's easier to make
  # changes to whilst allowing us to keep the last value provided for a key. This
  # is not required by the spec, but seems to be standard so we should keep to it.
  defp decode_object(<< "\"", bin :: binary >>, acc) do
    { << ":", rem1 :: binary >>, key } = decode_string(bin, "")
    { rem2, val } = do_decode(strip_ws(rem1))
    enforce_object_terminator(rem2, [ { key, val } | acc ])
  end
  defp decode_object(<< "}", rest :: binary >>, []), do: { strip_ws(rest), %{} }

  # Because the remainders passed in have had leading whitespace trimmed, the
  # only valid characters to come next are the comma and the curly terminator.
  # If we receive a comma, we remove whitespace after it and pass the remainder
  # back through to the initial array decoder. If we've hit the end of the input
  # then we just remove the leading whitespace, and construct a map from the
  # values - making sure that we reverse to keep the last value set for a key.
  defp enforce_object_terminator(<< ",", rest :: binary >>, acc),
    do: decode_object(strip_ws(rest), acc)
  defp enforce_object_terminator(<< "}", rest :: binary >>, acc),
    do: { strip_ws(rest), :maps.from_list(:lists.reverse(acc)) }

  # Entry point for decoding a string value into a binary. This has to deal with
  # escape sequences and as such this is the bottleneck in decoding (taking up
  # roughly 60-80% of the execution time). In the case we receive a backslash,
  # we have to pass through the string to be escaped correctly using the function
  # `string_escape/1`. We pass the remainder back through to `decode_string/2`
  # recursively as we can just keep moving through the string in the same way.
  # If we receive a `"`, we're officially done (as escaped quotes will be caught
  # by the first function head). Anything else and we move through the binary
  # by subreferencing and finding blocks of valid input to avoid writing often.
  # We then just pass back through to the same function in order to handle the
  # escaping checking of potentially invalid input to make sure we can reject.
  defp decode_string(<< "\\", rest :: binary >>, acc) do
    { remainder, value } = string_escape(rest)
    decode_string(remainder, [ acc, value ])
  end
  defp decode_string(<< "\"", rest :: binary >>, acc),
    do: { strip_ws(rest), :erlang.iolist_to_binary(acc) }
  defp decode_string(bin, acc) do
    valid_count = detect_string(bin, 0, &shift_point/3)
    << value :: binary-size(valid_count), rest :: binary >> = bin
    decode_string(rest, [ acc, value ])
  end

  # Shifts an accumulator along based upon the value of the start UTF-8 codepoint.
  # This allows us to iterate along a binary whilst tracking unicode characters.
  defp shift_point(<< val :: utf8, rest :: binary >>, acc, ca),
    do: detect_string(rest, acc + cp_value(val), ca)

  # Welcome to the land of unicode and escapes. This is where we make sure that
  # incoming sequences are correctly escaped and converted correctly. The first
  # thing to verify is that any JSON valid sequences are correctly escaped using
  # a simple function head match to ensure as such. The annoyance comes when the
  # escape sequence is of the form `\u\d{4}` as we have to parse into a UTF-8
  # codepoint, which isn't easy - this is handled by the last function head.
  # The middle function head handles what's known as surrogate pairs. These values
  # are essentially two 16-bit units which mean something more than their own
  # value when combined. Due to this we have to match on the full two units and
  # enforce some rules related to what makes a surrogate pair (in the guards),
  # before converting the pair to a codepoint. If this is confusing, the Wiki
  # page for UTF-16 has a fairly good overview of what exactly is going on here.
  for { key, replace } <- List.zip(['"\\ntr/fb', '"\\\n\t\r/\f\b']) do
    defp string_escape(<< unquote(key), rest :: binary >>),
      do: { rest, unquote(replace) }
  end
  defp string_escape(<< ?u, l1, l2, l3, l4, "\\u", r1, r2, r3, r4, rest :: binary >>)
  when l1 in 'dD' and r1 in 'dD' and l2 in '89abAB' and r2 in 'cdefCDEF' do
    c1 = :erlang.list_to_integer([l1, l2, l3, l4], 16) &&& 0x03FF
    c2 = :erlang.list_to_integer([r1, r2, r3, r4], 16) &&& 0x03FF
    { rest, << (0x10000 + (c1 <<< 10) + c2) :: utf8 >> }
  end
  defp string_escape(<< ?u, seq :: binary-4, rest :: binary >>),
    do: { rest, << :erlang.binary_to_integer(seq, 16) :: utf8 >> }

  ############
  # Utilities
  ############

  # Calculates the length of a codepoint as used in `dectect_string/2` to move
  # along the string input a given amount of places. Abstracted out to remove
  # code bloat based on function head matching.
  defp cp_value(val) when val < 0x800, do: 2
  defp cp_value(val) when val < 0x10000, do: 3
  defp cp_value(_val), do: 4

  # This function essentially pulls back a count of valid bytes inside the input,
  # by moving through and validating against various characters to determine if
  # we can continue or not. If we can't, we return the count so that we can then
  # use it to pull a reference back without having to carry out writes. If we
  # can we just keep on moving through by calling this function recursively and
  # incrementing the counter used as an accumulator. Note that we increment by
  # more than just `1` depending on where the codepoint value lies in the table.
  defp detect_string(<< val, _rest :: binary >>, acc, _ca) when val <= 0x1F,
    do: valid_count!(acc)
  defp detect_string(<< val, _rest :: binary >>, acc, _ca) when val in '"\\',
    do: valid_count!(acc)
  defp detect_string(<< val, rest :: binary >>, acc, ca) when val < 0x80,
    do: detect_string(rest, acc + 1, ca)
  defp detect_string(bin, acc, ca),
    do: ca.(bin, acc, ca)

  # Strips leading whitespace from an input binary, by subreferencing the binary.
  # This means that we don't create anything new, purely reference what already
  # exists. We make sure to cover all forms of whitespace when stripping.
  defp strip_ws(<< v, rest :: binary >>) when v in '\s\n\t\r', do: strip_ws(rest)
  defp strip_ws(rest), do: rest

  # Simply checks to see whether we have a valid count or not - with a valid
  # count being anything that's above zero. We don't deal in negatives anywhere
  # so there's no need to check them - they would crash anyway later on.
  defp valid_count!(0), do: raise ArgumentError
  defp valid_count!(x), do: x

  # Wraps a provided function to execute with the provided input and options,
  # whilst protecting against errors being thrown in order to safely return an
  # `:error` Tuple. In the case that the execution is successful, then we return
  # the result of the function in an `:ok` Tuple to signal as such to the caller.
  defp wrap(fun, input, opts) do
    { :ok, fun.(input, opts) }
  rescue _ ->
    { :error, :invalid_input }
  end

end
