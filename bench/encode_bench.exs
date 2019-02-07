defmodule EncodeBench do
  use Benchfella

  ###########################
  # Encoding of large input #
  ###########################

  bench "encode (large) (jiffy)", [ input: gen_large_sample() ] do
    :jiffy.encode(input)
    :ok
  end

  bench "encode (large) (jason)", [ input: gen_large_sample() ] do
    Jason.encode!(input)
    :ok
  end

  bench "encode (large) (jsx)", [ input: gen_large_sample() ] do
    JSX.encode!(input)
    :ok
  end

  bench "encode (large) (poison)", [ input: gen_large_sample() ] do
    Poison.encode!(input)
    :ok
  end

  bench "encode (large) (tiny)", [ input: gen_large_sample() ] do
    Tiny.encode!(input)
    :ok
  end

  ###########################
  # Encoding of small input #
  ###########################

  bench "encode (small) (jiffy)", [ input: gen_small_sample() ] do
    :jiffy.encode(input)
    :ok
  end

  bench "encode (small) (jason)", [ input: gen_small_sample() ] do
    Jason.encode!(input)
    :ok
  end

  bench "encode (small) (jsx)", [ input: gen_small_sample() ] do
    JSX.encode!(input)
    :ok
  end

  bench "encode (small) (poison)", [ input: gen_small_sample() ] do
    Poison.encode!(input)
    :ok
  end

  bench "encode (small) (tiny)", [ input: gen_small_sample() ] do
    Tiny.encode!(input)
    :ok
  end

  #################
  # Utility stuff #
  #################

  defp gen_small_sample,
    do: gen_sample("small.json")

  defp gen_large_sample,
    do: gen_sample("large.json")

  defp gen_sample(name) do
    "resources/#{name}"
    |> Path.expand(__DIR__)
    |> File.read!
    |> Tiny.decode!
  end

end
