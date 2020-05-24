defmodule ManagerTest do
  use ExUnit.Case

  setup do
    Application.put_env(:crawly, :concurrent_requests_per_domain, 1)
    Application.put_env(:crawly, :closespider_itemcount, 10)

    :meck.expect(HTTPoison, :get, fn _, _, _ ->
      {:ok,
       %HTTPoison.Response{
         status_code: 200,
         body: "Some page",
         headers: [],
         request: %{}
       }}
    end)

    on_exit(fn ->
      :meck.unload(HTTPoison)
      Application.put_env(:crawly, :manager_operations_timeout, 30_000)
      Application.put_env(:crawly, :concurrent_requests_per_domain, 1)
      Application.put_env(:crawly, :closespider_timeout, 20)
      Application.put_env(:crawly, :closespider_itemcount, 100)
    end)
  end

  test "test normal spider behavior" do
    :ok = Crawly.Engine.start_spider(ManagerTestSpider)

    {:stored_requests, num} = Crawly.RequestsStorage.stats(ManagerTestSpider)
    assert num == 1
    Process.sleep(5_00)

    {:stored_items, num} = Crawly.DataStorage.stats(ManagerTestSpider)
    assert num == 1

    :ok = Crawly.Engine.stop_spider(ManagerTestSpider)
    assert [] == Crawly.Engine.running_spiders()
  end

  test "Closespider itemcount is respected" do
    Application.put_env(:crawly, :manager_operations_timeout, 1_000)
    Application.put_env(:crawly, :closespider_timeout, 1)
    Application.put_env(:crawly, :concurrent_requests_per_domain, 5)
    Application.put_env(:crawly, :closespider_itemcount, 3)
    :ok = Crawly.Engine.start_spider(ManagerTestSpider)

    Process.sleep(2_000)
    assert [] == Crawly.Engine.running_spiders()
  end

  test "Closespider timeout is respected" do
    Application.put_env(:crawly, :manager_operations_timeout, 1_000)
    Application.put_env(:crawly, :concurrent_requests_per_domain, 1)
    :ok = Crawly.Engine.start_spider(ManagerTestSpider)
    Process.sleep(2_000)
    assert [] == Crawly.Engine.running_spiders()
  end

  test "Can't start already started spider" do
    :ok = Crawly.Engine.start_spider(ManagerTestSpider)

    assert {:error, :spider_already_started} ==
             Crawly.Engine.start_spider(ManagerTestSpider)

    :ok = Crawly.Engine.stop_spider(ManagerTestSpider)
  end

  test "Can't stop the spider which is not started already started spider" do
    :ok = Crawly.Engine.start_spider(ManagerTestSpider)

    assert {:error, :spider_already_started} ==
             Crawly.Engine.start_spider(ManagerTestSpider)

    :ok = Crawly.Engine.stop_spider(ManagerTestSpider)
  end

  test "Spider closed callback is called when spider is stopped" do
    Process.register(self(), :spider_closed_callback_test)
    :ok = Crawly.Engine.start_spider(ManagerTestSpider)
    :ok = Crawly.Engine.stop_spider(ManagerTestSpider, :manual_stop)

    assert_receive :manual_stop
  end
end
