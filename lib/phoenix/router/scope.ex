defmodule Phoenix.Router.Scope do
  @moduledoc false

  @stack :phoenix_router_scopes

  @doc """
  Builds a route based on the top of the stack.
  """
  def route(module, verb, path, controller, action, options) do
    as = Keyword.get(options, :as, Phoenix.Naming.resource_name(controller, "Controller"))
    {path, alias, as, pipe_through} = join(module, path, controller, as)
    Phoenix.Router.Route.build(verb, path, alias, action, as, pipe_through)
  end

  @doc """
  Appends to the current scope pipe through.
  """
  def pipe_through(module, pipes) do
    update_stack(module, fn [scope|stack] ->
      scope = put_elem(scope, 3, elem(scope, 3) ++ List.wrap(pipes))
      [scope|stack]
    end)
  end

  @doc """
  Pushes a scope into the module stack.
  """
  def push(module, opts) do
    path  = Keyword.get(opts, :path)
    if path, do: path = Plug.Router.Utils.split(path)

    alias = Keyword.get(opts, :alias)
    if alias, do: alias = Atom.to_string(alias)

    as = Keyword.get(opts, :as)
    scope = {path, alias, as, []}
    update_stack(module, fn stack -> [scope|stack] end)
  end

  @doc """
  Pops a scope from the module stack.
  """
  def pop(module) do
    update_stack(module, fn [_|stack] -> stack end)
  end

  defp join(module, path, alias, as) do
    stack = get_stack(module)
    {join_path(stack, path), join_alias(stack, alias),
     join_as(stack, as), join_pipe_through(stack)}
  end

  defp join_path(stack, path) do
    "/" <>
      ([Plug.Router.Utils.split(path)|extract(stack, 0)]
       |> Enum.reverse()
       |> Enum.concat()
       |> Enum.join("/"))
  end

  defp join_alias(stack, alias) when is_atom(alias) do
    [alias|extract(stack, 1)]
    |> Enum.reverse()
    |> Module.concat()
  end

  defp join_as(_stack, nil), do: nil
  defp join_as(stack, as) when is_atom(as) or is_binary(as) do
    [as|extract(stack, 2)]
    |> Enum.reverse()
    |> Enum.join("_")
  end

  defp join_pipe_through(stack) do
    for tuple <- Enum.reverse(stack),
        item <- elem(tuple, 3),
        do: item
  end

  defp extract(stack, pos) do
    for tuple <- stack,
        item = elem(tuple, pos),
        do: item
  end

  defp get_stack(module) do
    Module.get_attribute(module, @stack) || []
  end

  defp update_stack(module, fun) do
    Module.put_attribute(module, @stack, fun.(get_stack(module)))
  end
end
