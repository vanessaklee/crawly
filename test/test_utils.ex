defmodule TestUtils do
  def stop_process(pid) do
    :erlang.exit(pid, :shutdown)
    wait_pid(pid)
    :ok
  end

  def wait_pid(pid, timeout \\ 5_000) do
    :erlang.monitor(:process, pid)

    result =
      receive do
        {:DOWN, _, _, ^pid, reason} -> {:ok, reason}
      after
        timeout -> timeout
      end

    result
  end
end

defmodule TestSpider do
  use Crawly.Spider

  def base_url() do
    "https://www.example.com"
  end

  def init() do
    [
      start_urls: ["https://www.example.com/blog.html"]
    ]
  end

  def parse_item(_response) do
    path = Enum.random(1..100)

    %Crawly.ParsedItem{
      :items => [
        %{title: "t_#{path}", url: "example.com", author: "Me", time: "not set"}
      ],
      :requests => [
        Crawly.Utils.request_from_url("https://www.example.com/#{path}")
      ]
    }
  end
end

defmodule UtilsTestSpider do
  use GenServer
  use Crawly.Spider

  @impl true
  def init(init_arg) do
    {:ok, init_arg}
  end

  @impl Crawly.Spider
  def base_url() do
    "https://www.example.com"
  end

  @impl Crawly.Spider
  def init() do
    [
      start_urls: ["https://www.example.com"]
    ]
  end

  @impl Crawly.Spider
  def parse_item(_response) do
    {[], []}
  end
end

defmodule ManagerTestSpider do
  use Crawly.Spider

  def override_settings() do
    on_spider_closed_callback = fn reason ->
      case Process.whereis(:spider_closed_callback_test) do
        nil ->
          :nothing_to_do

        _pid ->
          send(:spider_closed_callback_test, reason)
      end
    end

    [on_spider_closed_callback: on_spider_closed_callback]
  end

  def base_url() do
    "https://www.example.com"
  end

  def init() do
    [
      start_urls: ["https://www.example.com/blog.html"]
    ]
  end

  def parse_item(_response) do
    path = Enum.random(1..100)

    %{
      :items => [
        %{title: "t_#{path}", url: "example.com", author: "Me", time: "not set"}
      ],
      :requests => [
        Crawly.Utils.request_from_url("https://www.example.com/#{path}")
      ]
    }
  end

  def spider_closed(:manual_stop) do
    send(:spider_closed_callback_test, :manual_stop)
  end

  def spider_closed(_) do
    :ignored
  end
end
