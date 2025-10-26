<div align="center">
<img src="priv/static/favicon/android-chrome-192x192.png" alt="aoe4stats.com logo" />
<h1>AOE4STATS.COM</h1>
</div>

### Motivation

I built it to explore Elixir and Phoenix in a way that relates to my passion for RTS games.

### Under the hood

The app is pulling data from another Age Of Empires IV API and tranforming it in ways to yield stastical data that is not available elsewhere. The player data relates to the 1v1 ladder performance in the game. The app is hosted on Fly.io.

#### Sections:

- The Map Win Rate section aggregates stasistics for each map, civilization and league bracket to surface granular balance data.
- The Rating section shows 5, 10 and 20 game moving average rating information.
- The Game Length section shows the player's win rates in different game length brackets which is significant due to how the game is played over time (progressing from Feudal to Castle to Imperial age). Early gameplay is more micromanagement oriented and conversely late-game is more about macro.
- The Opponents section is geographical represenation of the origin of the player's opponents.
- The Insights section throws the entire payload of player data at `grok-4-fast-reasoning` with a custom prompt to extract patterns pertaning to the player's performance.

### Usage example

[BeastyQt](https://liquipedia.net/ageofempires/Beastyqt) is a famous ex-Stacraft 2 and current Age of Empires IV professional gamer. You can search for _Beasty_ in the Player Statistic section of the app to see data relevant to him. You can also try one of the other current top ladder players:
_Valdemar_, _Fox.Anotand_, _El.loueMT_ or _Liquid`DeMu_ for example.

### Local Dev

To start your Phoenix server:

- Run `mix setup` to install and setup dependencies
- Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4001`](http://localhost:4001) from your browser.
