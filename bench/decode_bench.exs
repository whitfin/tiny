defmodule DecodeBench do
  use Benchfella

  ###########################
  # Decoding of large input #
  ###########################

  bench "decode (large) (jiffy)", [ input: gen_large_sample() ] do
    :jiffy.decode(input, [ :return_maps ])
    :ok
  end

  bench "decode (large) (json)", [ input: gen_large_sample() ] do
    JSON.decode!(input)
    :ok
  end

  bench "decode (large) (jsx)", [ input: gen_large_sample() ] do
    JSX.decode!(input, [ :strict ])
    :ok
  end

  bench "decode (large) (poison)", [ input: gen_large_sample() ] do
    Poison.decode!(input)
    :ok
  end

  bench "decode (large) (tiny)", [ input: gen_large_sample() ] do
    Tiny.decode!(input)
    :ok
  end

  ###########################
  # Decoding of small input #
  ###########################

  bench "decode (small) (jiffy)", [ input: gen_small_sample() ] do
    :jiffy.decode(input, [ :return_maps ])
    :ok
  end

  bench "decode (small) (json)", [ input: gen_small_sample() ] do
    JSON.decode!(input)
    :ok
  end

  bench "decode (small) (jsx)", [ input: gen_small_sample() ] do
    JSX.decode!(input, [ :strict ])
    :ok
  end

  bench "decode (small) (poison)", [ input: gen_small_sample() ] do
    Poison.decode!(input)
    :ok
  end

  bench "decode (small) (tiny)", [ input: gen_small_sample() ] do
    Tiny.decode!(input)
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
  end

end
