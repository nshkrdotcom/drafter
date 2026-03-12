defmodule Drafter.Terminal.TermiosNif do
  @moduledoc false

  @on_load :load_nif

  def load_nif do
    nif_path = :filename.join(:code.priv_dir(:drafter), ~c"termios_nif")
    :erlang.load_nif(nif_path, 0)
  end

  def disable_flow_control do
    :erlang.nif_error(:not_loaded)
  end

  def enable_flow_control do
    :erlang.nif_error(:not_loaded)
  end

  def enter_raw_mode do
    :erlang.nif_error(:not_loaded)
  end

  def exit_raw_mode do
    :erlang.nif_error(:not_loaded)
  end
end
