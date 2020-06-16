defmodule Majic.PlugTest do
  use ExUnit.Case, async: true
  use Plug.Test

  defmodule TestRouter do
    use Plug.Router

    plug(:match)
    plug(:dispatch)

    plug(Plug.Parsers,
      parsers: [:urlencoded, :multipart],
      pass: ["*/*"]
    )

    # plug Majic.Plug, once: true

    post "/" do
      send_resp(conn, 200, "Ok")
    end
  end

  setup_all do
    Application.ensure_all_started(:plug)
    :ok
  end

  @router_opts TestRouter.init([])

  test "convert uploads" do
    multipart = """
    ------w58EW1cEpjzydSCq\r
    Content-Disposition: form-data; name=\"form[makefile]\"; filename*=\"utf-8''mymakefile.txt\"\r
    Content-Type: text/plain\r
    \r
    #{String.replace(File.read!("Makefile"), "\n", "\n")}\r
    ------w58EW1cEpjzydSCq\r
    Content-Disposition: form-data; name=\"form[make][file]\"; filename*=\"utf-8''mymakefile.txt\"\r
    Content-Type: text/plain\r
    \r
    #{String.replace(File.read!("Makefile"), "\n", "\n")}\r
    ------w58EW1cEpjzydSCq\r
    Content-Disposition: form-data; name=\"cat\"; filename*=\"utf-8''cute-cat.jpg\"\r
    Content-Type: image/jpg\r
    \r
    #{String.replace(File.read!("test/fixtures/cat.webp"), "\n", "\n")}\r
    ------w58EW1cEpjzydSCq--\r
    """

    orig_conn =
      conn(:post, "/", multipart)
      |> put_req_header("content-type", "multipart/mixed; boundary=----w58EW1cEpjzydSCq")
      |> TestRouter.call(@router_opts)

    plug = Majic.Plug.init(once: true)
    plug_no_ext = Majic.Plug.init(once: true, fix_extension: false)
    plug_append_ext = Majic.Plug.init(once: true, fix_extension: true, append_extension: true)

    conn = Majic.Plug.call(orig_conn, plug)
    conn_no_ext = Majic.Plug.call(orig_conn, plug_no_ext)
    conn_append_ext = Majic.Plug.call(orig_conn, plug_append_ext)

    assert conn.state == :sent
    assert conn.status == 200

    refute get_in(conn.body_params, ["form", "makefile"]).content_type ==
             get_in(conn.params, ["form", "makefile"]).content_type

    assert get_in(conn.params, ["form", "makefile"]).content_type == "text/x-makefile"
    assert get_in(conn.params, ["form", "makefile"]).filename == "mymakefile"
    assert get_in(conn_no_ext.params, ["form", "makefile"]).filename == "mymakefile.txt"
    assert get_in(conn_append_ext.params, ["form", "makefile"]).filename == "mymakefile.txt"

    refute get_in(conn.body_params, ["form", "make", "file"]).content_type ==
             get_in(conn.params, ["form", "make", "file"]).content_type

    assert get_in(conn.params, ["form", "make", "file"]).content_type == "text/x-makefile"

    refute get_in(conn.body_params, ["cat"]).content_type ==
             get_in(conn.params, ["cat"]).content_type

    assert get_in(conn.params, ["cat"]).content_type == "image/webp"
    assert get_in(conn.params, ["cat"]).filename == "cute-cat.webp"
    assert get_in(conn_no_ext.params, ["cat"]).filename == "cute-cat.jpg"
    assert get_in(conn_append_ext.params, ["cat"]).filename == "cute-cat.jpg.webp"
  end
end