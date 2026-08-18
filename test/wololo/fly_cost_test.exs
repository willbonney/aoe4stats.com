defmodule Wololo.FlyCostTest do
  use ExUnit.Case, async: true

  alias Wololo.FlyCost

  test "prices a started shared-cpu-1x 2GB machine in dfw" do
    cost =
      FlyCost.estimate_from_resources(%{
        machines: [
          %{state: "started", region: "dfw", cpu_kind: "shared", cpus: 1, memory_mb: 2048}
        ]
      })

    assert cost.amount == 13.37
    assert cost.label == "$13"
  end

  test "prices amsterdam cheaper than dallas for the same machine" do
    dfw =
      FlyCost.estimate_from_resources(%{
        machines: [
          %{state: "started", region: "dfw", cpu_kind: "shared", cpus: 1, memory_mb: 2048}
        ]
      })

    ams =
      FlyCost.estimate_from_resources(%{
        machines: [
          %{state: "started", region: "ams", cpu_kind: "shared", cpus: 1, memory_mb: 2048}
        ]
      })

    assert ams.amount == 11.11
    assert ams.amount < dfw.amount
  end

  test "charges stopped machines for rootfs only" do
    cost =
      FlyCost.estimate_from_resources(%{
        machines: [
          %{state: "stopped", region: "dfw", cpu_kind: "shared", cpus: 1, memory_mb: 2048}
        ]
      })

    assert cost.amount == 0.15
  end

  test "ignores destroyed machines" do
    cost =
      FlyCost.estimate_from_resources(%{
        machines: [
          %{state: "destroyed", region: "dfw", cpu_kind: "shared", cpus: 1, memory_mb: 2048},
          %{state: "started", region: "ams", cpu_kind: "shared", cpus: 1, memory_mb: 2048}
        ]
      })

    assert cost.amount == 11.11
  end

  test "adds dedicated ipv4 and volumes" do
    cost =
      FlyCost.estimate_from_resources(%{
        machines: [],
        dedicated_ipv4_count: 1,
        volume_gb: 10,
        certificate_count: 4
      })

    # $2 IPv4 + $1.50 volumes; first 10 certs are free
    assert cost.amount == 3.50
    assert cost.label == "$4"
  end

  test "charges certificates after the first 10" do
    cost = FlyCost.estimate_from_resources(%{certificate_count: 12})
    assert cost.amount == 0.20
  end
end
