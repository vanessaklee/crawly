defmodule EngineTest do
  use ExUnit.Case

  test "list_spiders/0 lists all spiders and their current status in the engine" do
    Crawly.Engine.init([])

    spiders = Crawly.Engine.list_spiders()
    assert [_ | _] = spiders
    assert status = Enum.find(spiders, fn s -> s.name == TestSpider end)
    assert status.status == :stopped

    # test a started spider
    Crawly.Engine.start_spider(TestSpider)

    assert started_status =
             Crawly.Engine.list_spiders()
             |> Enum.find(fn s -> s.name == TestSpider end)

    assert {:started, pid} = started_status.status
    assert pid

    # stop spider
    Crawly.Engine.stop_spider(TestSpider)
    spiders = Crawly.Engine.list_spiders()
    assert Enum.all?(spiders, fn s -> s.status == :stopped end)
  end
end
