defmodule Bluetooth.HCI.PortEmulator do
  @moduledoc """
  Emulates the port program for accessing HCI and enables testing
  on a host without accessing a real bluetooth device.

  """

  use GenServer
  require Logger

  # Constants for HCI commands etc
  @hci_command_package_type 1
  @hci_event_package_type 4

  def start_link(hci_device \\ 0) do
    GenServer.start_link(__MODULE__, [hci_device])
  end

  defstruct [hci_device: -1, filter: "", from: nil]

  def init([hci_device]) do
    {:ok, %__MODULE__{hci_device: hci_device}}
  end

  def handle_info({from, {:command, msg}}, state) when is_pid(from) and is_binary(msg) do
    {ref, {func, args}} = :erlang.binary_to_term(msg)
    state = %__MODULE__{state | from: from}
    {new_state, result} = apply(__MODULE__, func, [state | args])
    return_value = :erlang.term_to_binary({ref, result})
    send(from, {self(), {:data, return_value}})
    {:noreply, new_state}
  end

  def hci_init(state) do
    {state, :ok}
  end

  def hci_is_dev_up(state) do
    {state, true}
  end

  def hci_dev_id_for(state, true), do: {state, state.hci_device}
  def hci_dev_id_for(state, false), do: {state, nil}

  def hci_bind_raw(%__MODULE{hci_device: id} = state, dev_id) when dev_id == id do
    {state, dev_id}
  end
  def hci_bind_raw(state, _) , do: {state, -1}

  def hci_set_filter(state, filter_data) do
    new_state = %__MODULE__{state | filter: filter_data}
    {new_state, :ok}
  end

  def hci_send_command(state, command) do
    <<@hci_command_package_type :: integer-size(8),
      opcode :: unsigned-integer-little-size(16),
      len :: unsigned-integer-size(8),
      params :: binary>> = command
    <<
      ogf :: unsigned-integer-size(6),
      ocf :: unsigned-integer-size(10)
    >> = <<opcode :: unsigned-integer-size(16)>>
    do_command(ogf, ocf, params, state)
  end

  def do_command(0x04, 0x01, <<>>, state) do
    do_send_event(state.from, <<4, 14, 12, 1, 1, 16, 0, 7, 25, 18, 7, 15, 0, 119, 33>>)
    {state, :ok}
  end
  def do_command(ogf, ocf, params, state) do
    Logger.error "Unknown command: ogf: #{inspect ogf}, ocf: #{inspect ocf}, params: #{inspect params}"
    {:stop, {:error, :unknown_command}, state}
  end

  def do_send_event(pid, data) do
    msg = :erlang.term_to_binary({:event, data})
    send(pid, {self(), {:data, msg}})
  end

  def foo(state, x) do
    {state, x+1}
  end
end
