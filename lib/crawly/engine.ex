defmodule Crawly.Engine do
  @moduledoc """
  Crawly Engine - process responsible for starting and stopping spiders.

  Stores all currently running spiders.
  """
  require Logger

  use GenServer

  @type t() :: %__MODULE__{
          spiders: [spider_info()]
        }
  @type spider_info() :: %{
          name: module(),
          status: spider_status()
        }
  @type spider_status() :: :stopped | {:started, identifier()}

  defstruct(spiders: [])

  @spec start_spider(module()) ::
          :ok
          | {:error, :spider_already_started}
          | {:error, :atom}
  def start_spider(spider_name) do
    GenServer.call(__MODULE__, {:start_spider, spider_name})
  end

  @spec stop_spider(module(), reason) :: result
        when reason: :itemcount_limit | :itemcount_timeout | atom(),
             result:
               :ok | {:error, :spider_not_running} | {:error, :spider_not_found}
  def stop_spider(spider_name, reason \\ :ignore) do
    case Crawly.Utils.get_settings(:on_spider_closed_callback, spider_name) do
      nil -> :ignore
      fun -> apply(fun, [reason])
    end

    GenServer.call(__MODULE__, {:stop_spider, spider_name})
  end

  @spec list_spiders() :: [spider_info()]
  def list_spiders() do
    GenServer.call(__MODULE__, :list_spiders)
  end

  @spec running_spiders() :: [spider_info()]
  def running_spiders() do
    GenServer.call(__MODULE__, :running_spiders)
  end

  @spec get_spider(module()) :: spider_info()
  def get_spider(name) do
    GenServer.call(__MODULE__, {:get_spider, name})
  end

  def refresh_spiders() do
    GenServer.cast(__MODULE__, :refresh_spiders)
  end

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @spec init(any) :: {:ok, __MODULE__.t()}
  def init(_args) do
    spiders = do_refresh_spiders()

    {:ok, %Crawly.Engine{spiders: spiders}}
  end

  def handle_call(:running_spiders, _from, state) do
    state = maybe_refresh_state(state)

    started_spiders =
      state.spiders
      |> Enum.filter(fn s -> match?({:started, _pid}, s.status) end)

    {:reply, started_spiders, state}
  end

  def handle_call({:get_spider, spider_name}, _from, state) do
    state = maybe_refresh_state(state)
    spider = do_get_spider_info(state.spiders, spider_name)
    {:reply, spider, state}
  end

  def handle_call(:list_spiders, _from, state) do
    state = maybe_refresh_state(state)

    {:reply, state.spiders, state}
  end

  def handle_call({:start_spider, spider_name}, _form, state) do
    state = maybe_refresh_state(state)

    result =
      case do_get_spider_info(state.spiders, spider_name) do
        %{status: :stopped} ->
          Crawly.EngineSup.start_spider(spider_name)

        %{status: {:started, _}} ->
          {:error, :spider_already_started}

        nil ->
          {:error, :spider_not_found}
      end

    {msg, new_spiders} =
      case result do
        {:ok, pid} ->
          # update spider info
          new_spiders =
            do_update_spider_info(
              state.spiders,
              spider_name,
              :status,
              {:started, pid}
            )

          {:ok, new_spiders}

        {:error, _} = err ->
          {err, state.spiders}
      end

    {:reply, msg, %{state | spiders: new_spiders}}
  end

  def handle_call({:stop_spider, spider_name}, _form, state) do
    state = maybe_refresh_state(state)

    with %{status: {:started, pid}} <-
           do_get_spider_info(state.spiders, spider_name) do
      Crawly.EngineSup.stop_spider(pid)

      new_spiders =
        do_update_spider_info(state.spiders, spider_name, :status, :stopped)

      {:reply, :ok, %Crawly.Engine{state | spiders: new_spiders}}
    else
      %{status: :stopped} ->
        {:reply, {:error, :spider_not_running}, state}
    end
  end

  def handle_cast(:refresh_spiders, state) do
    spiders = do_refresh_spiders(state.spiders)
    {:noreply, %{state | spiders: spiders}}
  end

  defp maybe_refresh_state(%{spiders: []} = state) do
    %{state | spiders: do_refresh_spiders()}
  end

  defp maybe_refresh_state(state), do: state

  defp do_refresh_spiders(current_spiders \\ []) do
    started = do_list_started_spiders(current_spiders)

    all =
      Crawly.Utils.list_spiders()
      |> Enum.map(fn name -> %{name: name, status: :stopped} end)

    (started ++ all)
    |> Enum.dedup_by(fn x -> x.name end)
  end

  defp do_list_started_spiders(spiders) do
    spiders
    |> Enum.filter(fn s -> match?({:started, _pid}, s.status) end)
  end

  defp do_update_spider_info(spiders, spider_name, key, value) do
    Enum.map(
      spiders,
      &if(Map.get(&1, :name) == spider_name,
        do: Map.put(&1, key, value),
        else: &1
      )
    )
  end

  defp do_get_spider_info(spiders, name) do
    Enum.find(spiders, nil, fn s -> s.name == name end)
  end
end
