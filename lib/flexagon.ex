defmodule Flexagon do
  use Plug.Router
  import Plug.Conn

  if Mix.env == :dev do
    use Plug.Debugger
  end

  @version Mix.Project.config[:version]

  plug Plug.RequestId
  plug Plug.Logger
  plug :match
  plug :dispatch

  def start(_type, _argv) do
    port = Application.get_env(:flexagon, :port)
    IO.puts "Running Flexagon with Cowboy on http://localhost:#{port}"
    Plug.Adapters.Cowboy.http __MODULE__, [], port: port
  end

  get "/" do
    conn
    |> put_resp_header("server", "flexagon")
    |> put_resp_header("cache-control", "public")
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(%{verison: @version, name: "flexagon"}))
  end

  get "/@:scoped_package" do
    [scope, package] = String.split scoped_package, "/"
    headers = :hackney_headers.new(conn.req_headers)
    headers = :hackney_headers.delete("accept-encoding", headers)
    headers = :hackney_headers.store("host", scope_target, headers)
    headers = :hackney_headers.store("x-forwarded-for", remote_ip(conn), headers)
    headers = :hackney_headers.insert("via", "1.1 flexagon", headers)
    headers = :hackney_headers.to_list(headers)
    {:ok, client} = HTTPoison.get("http://#{scope_target}/@#{scope}%2F#{package}", headers)

    conn
    |> read_proxy(client)
  end

  get "/@:scope/:package/-/:tarball" do
    headers = :hackney_headers.new(conn.req_headers)
    headers = :hackney_headers.store("host", scope_target, headers)
    headers = :hackney_headers.store("x-forwarded-for", remote_ip(conn), headers)
    headers = :hackney_headers.insert("via", "1.1 flexagon", headers)
    headers = :hackney_headers.to_list(headers)
    HTTPoison.get!("http://#{scope_target}/@#{scope}/#{package}/-/#{tarball}", headers, stream_to: self)

    stream_async_response(conn)
  end

  get "/:package/-/:tarball" do
    headers = :hackney_headers.new(conn.req_headers)
    headers = :hackney_headers.store("host", target, headers)
    headers = :hackney_headers.store("x-forwarded-for", remote_ip(conn), headers)
    headers = :hackney_headers.insert("via", "1.1 flexagon", headers)
    headers = :hackney_headers.to_list(headers)
    {:ok, _} = HTTPoison.get("http://#{target}/#{package}/-/#{tarball}", headers, stream_to: self)

    stream_async_response(conn)
  end

  get "/:package/*paths" do
    headers = :hackney_headers.new(conn.req_headers)
    headers = :hackney_headers.delete("accept-encoding", headers)
    headers = :hackney_headers.store("host", target, headers)
    headers = :hackney_headers.store("x-forwarded-for", remote_ip(conn), headers)
    headers = :hackney_headers.insert("via", "1.1 flexagon", headers)
    headers = :hackney_headers.to_list(headers)
    {:ok, client} = HTTPoison.get("http://#{target}/#{package}/" <> Enum.join(paths, "/"), headers)

    conn
    |> read_proxy(client)
  end

  match _ do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, Poison.encode!(%{error: "not_found", reason: "document not found"}))
  end

  defp stream_async_response(conn) do
    receive do
      %HTTPoison.AsyncStatus{code: status_code} ->
        conn
        |> put_status(status_code)
        |> stream_async_response
      %HTTPoison.AsyncHeaders{headers: headers} ->
        headers = :hackney_headers.new(headers)
        headers = :hackney_headers.insert("via", "1.1 flexagon", headers)
        headers = :hackney_headers.to_list(headers)

        %{conn | resp_headers: downcase_headers(headers)}
        |> send_chunked(conn.status)
        |> stream_async_response
      %HTTPoison.AsyncChunk{chunk: new_chunk} ->
        {:ok, conn} = chunk(conn, new_chunk)
        stream_async_response(conn)
      %HTTPoison.AsyncEnd{} ->
        conn
    end
  end

  defp read_proxy(conn, client) do
    case client do
      %HTTPoison.Response{status_code: status_code, body: body, headers: headers} ->
        headers = :hackney_headers.new(headers)
        headers = :hackney_headers.delete("transfer-encoding", headers)
        headers = :hackney_headers.insert("via", "1.1 flexagon", headers)

        if :hackney_headers.get_value("content-type", headers) == "application/json" do
          headers = :hackney_headers.delete("content-length", headers)

          body = body
          |> Poison.decode!
          |> rewrite_tarballs_uri
          |> Poison.encode!
        end

        if status_code == 304 do
          body = body
        end

        headers = :hackney_headers.to_list(headers)

        %{conn | resp_headers: downcase_headers(headers)}
        |> send_resp(status_code, body)
    end
  end

  defp rewrite_tarballs_uri(json) do
    cond do
      Map.has_key?(json, "versions") ->
        Map.update!(json, "versions", fn
          versions ->
            Enum.reduce(versions, %{}, fn
              ({version, data}, acc) ->
                Map.put(acc, version, update_in(data["dist"]["tarball"], &rewrite_uri/1))
            end)
        end)
      json["dist"]["tarball"] ->
        update_in(json, ["dist", "tarball"], &rewrite_uri/1)
      true ->
        json
    end
  end

  defp rewrite_uri(uri) do
    URI.parse(uri)
    |> Map.put(:host, "localhost")
    |> Map.put(:port, port)
    |> URI.to_string
  end

  defp downcase_headers(headers) do
    Enum.map(headers, fn
      {key, value} ->
        {String.downcase(key), value}
    end)
  end

  defp remote_ip(conn) do
    :inet.ntoa(conn.remote_ip) |> List.to_string
  end

  defp target do
    Application.get_env(:flexagon, :target)
  end

  defp scope_target do
    Application.get_env(:flexagon, :scope_target)
  end

  defp port do
    Application.get_env(:flexagon, :port)
  end
end
