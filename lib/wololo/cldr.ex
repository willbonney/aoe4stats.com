defmodule Wololo.Cldr do
  @moduledoc """
  Cldr backend module for internationalization
  """

  use Cldr,
    locales: ["en"],
    default_locale: "en",
    providers: [Cldr.Number, Cldr.Territory]
end
