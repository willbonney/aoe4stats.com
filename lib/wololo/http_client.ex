defmodule Wololo.HTTPClient do
  require Logger

  @timeout Application.compile_env(:wololo, [:http_client, :timeout], 30_000)
  @max_retries Application.compile_env(:wololo, [:http_client, :max_retries], 3)

  def get(url, headers \\ []) do
    Logger.debug("Making HTTP GET request to: #{url}")
    request = Finch.build(:get, url, headers)

    case Finch.request(request, Wololo.Finch, receive_timeout: @timeout) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        Logger.debug("HTTP GET request successful")
        {:ok, body}

      {:ok, %Finch.Response{status: status_code}} ->
        Logger.error("HTTP request failed with status code: #{status_code} for URL: #{url}")
        {:error, "HTTP request failed with status code: #{status_code}"}

      {:error, %Finch.Error{reason: reason}} ->
        Logger.error("HTTP request failed: #{reason} for URL: #{url}")
        {:error, "HTTP request failed: #{reason}"}

      {:error, %Mint.TransportError{reason: reason}} ->
        Logger.error("HTTP transport error: #{reason} for URL: #{url}")
        {:error, "HTTP transport error: #{reason}"}

      {:error, error} ->
        Logger.error("HTTP unexpected error: #{inspect(error)} for URL: #{url}")
        {:error, "HTTP unexpected error: #{inspect(error)}"}
    end
  end

  def get_with_retry(url, headers \\ [], retries \\ @max_retries) do
    case get(url, headers) do
      {:ok, body} ->
        {:ok, body}

      {:error, _reason} when retries > 0 ->
        Logger.info("Retrying HTTP request, #{retries} attempts remaining")
        # Wait 1 second before retry
        Process.sleep(1000)
        get_with_retry(url, headers, retries - 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def post(url, body, headers \\ []) do
    request = Finch.build(:post, url, headers, body)

    case Finch.request(request, Wololo.Finch, receive_timeout: @timeout) do
      {:ok, %Finch.Response{status: 200, body: response_body}} ->
        {:ok, response_body}

      {:ok, %Finch.Response{status: status_code, body: response_body}} ->
        Logger.error("HTTP POST request failed with status code: #{status_code}")
        Logger.error("Response body: #{response_body}")
        {:error, "HTTP POST request failed with status code: #{status_code}"}

      {:error, %Finch.Error{reason: reason}} ->
        Logger.error("HTTP POST request failed: #{reason}")
        {:error, "HTTP POST request failed: #{reason}"}

      {:error, %Mint.TransportError{reason: reason}} ->
        Logger.error("HTTP POST transport error: #{reason}")
        {:error, "HTTP POST transport error: #{reason}"}

      {:error, error} ->
        Logger.error("HTTP POST unexpected error: #{inspect(error)}")
        {:error, "HTTP POST unexpected error: #{inspect(error)}"}
    end
  end
end
