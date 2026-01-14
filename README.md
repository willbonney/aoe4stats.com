<div align="center">
<img src="priv/static/favicon/android-chrome-192x192.png" alt="aoe4stats.com logo" />
<h1>AOE4STATS.COM</h1>
</div>

<svg width="1200" height="650" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <marker id="arrowhead" markerWidth="12" markerHeight="8" refX="11" refY="4" orient="auto">
      <polygon points="0 0, 11 4, 0 8" fill="#333" stroke="none"/>
    </marker>
  </defs>
  <!-- Background -->
  <rect width="1200" height="650" fill="#fafafa" stroke="none"/>
  
  <!-- Client Box -->
  <rect x="40" y="230" width="200" height="90" rx="12" fill="#e3f2fd" stroke="#2196f3" stroke-width="4"/>
  <text x="140" y="265" font-family="Arial,sans-serif" font-size="16" font-weight="bold" text-anchor="middle" fill="#1976d2">Browser / LiveView</text>
  <text x="140" y="288" font-size="12" text-anchor="middle" fill="#1976d2">Tailwind CSS • Heroicons</text>
  
  <!-- Backend Boxes -->
  <rect x="290" y="80" width="220" height="70" rx="12" fill="#f3e5f5" stroke="#9c27b0" stroke-width="4"/>
  <text x="400" y="115" font-family="Arial,sans-serif" font-size="14" font-weight="bold" text-anchor="middle" fill="#7b1fa2">Bandit Server</text>
  <text x="400" y="135" font-size="12" text-anchor="middle">Port 4001</text>
  
  <rect x="290" y="170" width="220" height="60" rx="12" fill="#f3e5f5" stroke="#9c27b0" stroke-width="4"/>
  <text x="400" y="200" font-size="14" font-weight="bold" text-anchor="middle">Phoenix Router</text>
  <text x="400" y="218" font-size="11" text-anchor="middle">/players/:id etc.</text>
  
  <rect x="290" y="250" width="220" height="70" rx="12" fill="#f3e5f5" stroke="#9c27b0" stroke-width="4"/>
  <text x="400" y="282" font-size="14" font-weight="bold" text-anchor="middle">LiveViews</text>
  <text x="400" y="302" font-size="11" text-anchor="middle">Player Stats • Civs/Maps • Boards</text>
  
  <rect x="290" y="340" width="220" height="70" rx="12" fill="#f3e5f5" stroke="#9c27b0" stroke-width="4"/>
  <text x="400" y="372" font-size="14" font-weight="bold" text-anchor="middle">Contexts</text>
  <text x="400" y="392" font-size="11" text-anchor="middle">Fetchers • Transformers</text>
  
  <ellipse cx="530" cy="455" rx="70" ry="30" fill="#fff3e0" stroke="#ff9800" stroke-width="4"/>
  <text x="530" y="462" font-size="14" font-weight="bold" text-anchor="middle" fill="#f57c00">Cachex 💾</text>
  
  <!-- External Boxes -->
  <rect x="680" y="130" width="200" height="60" rx="12" fill="#e8f5e8" stroke="#4caf50" stroke-width="4"/>
  <text x="780" y="158" font-size="13" font-weight="bold" text-anchor="middle" fill="#388e3c">AOE4 API</text>
  <text x="780" y="178" font-size="11" text-anchor="middle">aoe4world.com Data</text>
  
  <rect x="680" y="220" width="200" height="60" rx="12" fill="#e8f5e8" stroke="#4caf50" stroke-width="4"/>
  <text x="780" y="248" font-size="13" font-weight="bold" text-anchor="middle" fill="#388e3c">Grok API</text>
  <text x="780" y="268" font-size="11" text-anchor="middle">Player Insights</text>
  
  <rect x="680" y="330" width="200" height="60" rx="12" fill="#e8f5e8" stroke="#4caf50" stroke-width="4"/>
  <text x="780" y="358" font-size="13" font-weight="bold" text-anchor="middle" fill="#388e3c">External Cron</text>
  <text x="780" y="378" font-size="11" text-anchor="middle">Leaderboard Updates</text>
  
  <!-- Bidirectional Arrows (double-ended, curved) -->
  <!-- Browser ↔ Bandit -->
  <path d="M240 275 Q280 220 290 115" stroke="#2196f3" stroke-width="5" fill="none" marker-end="url(#arrowhead)" marker-start="url(#arrowhead)"/>
  <text x="265" y="225" font-size="12" font-weight="bold" fill="#2196f3" text-anchor="middle">HTTP/WS ↔</text>
  
  <!-- Backend vertical chain (bidir) -->
  <path d="M400 150 L400 170" stroke="#9c27b0" stroke-width="5" fill="none" marker-end="url(#arrowhead)" marker-start="url(#arrowhead)"/>
  <text x="430" y="160" font-size="11" fill="#9c27b0">↔</text>
  
  <path d="M400 230 L400 250" stroke="#9c27b0" stroke-width="5" fill="none" marker-end="url(#arrowhead)" marker-start="url(#arrowhead)"/>
  <text x="430" y="240" font-size="11" fill="#9c27b0">↔</text>
  
  <path d="M400 320 L400 340" stroke="#9c27b0" stroke-width="5" fill="none" marker-end="url(#arrowhead)" marker-start="url(#arrowhead)"/>
  <text x="430" y="330" font-size="11" fill="#9c27b0">↔</text>
  
  <!-- Contexts ↔ Cachex -->
  <path d="M410 410 Q470 430 460 455" stroke="#ff9800" stroke-width="5" fill="none" marker-end="url(#arrowhead)" marker-start="url(#arrowhead)"/>
  <text x="475" y="435" font-size="11" fill="#ff9800">Cache ↔</text>
  
  <!-- Unidirectional (curved) -->
  <!-- Contexts → AOE4 -->
  <path d="M510 375 Q600 350 680 160" stroke="#4caf50" stroke-width="4" fill="none" marker-end="url(#arrowhead)"/>
  <text x="580" y="340" font-size="11" fill="#4caf50">Fetch →</text>
  
  <!-- Contexts → Grok -->
  <path d="M510 375 Q580 280 680 250" stroke="#4caf50" stroke-width="4" fill="none" marker-end="url(#arrowhead)"/>
  <text x="590" y="310" font-size="11" fill="#4caf50">Prompt →</text>
  
  <!-- Cron → Router -->
  <path d="M680 360 Q550 280 400 200" stroke="#4caf50" stroke-width="4" fill="none" marker-end="url(#arrowhead)"/>
  <text x="580" y="310" font-size="11" fill="#4caf50" transform="rotate(-45 580 310)">Trigger →</text>
</svg>


### Motivation

I built it to explore Elixir and Phoenix in a way that relates to my passion for RTS games.

### Under the hood

The app is pulling data from another Age Of Empires IV API and tranforming it in ways to yield stastical data that is not available elsewhere. The player data relates to the 1v1 ladder performance in the game. The app is hosted on Fly.io.

#### Sections

#### Civilizations & Maps
- The Map Win Rate section aggregates stasistics for each map, civilization and league bracket to surface granular balance data

#### Player Statistics
- The Rating section shows 5, 10 and 20 game moving average rating information and time spent in each league
- The Analysis section uses elegant math formulas to calculate 8 different metrics that assess skill in non-traditional ways
- The Rank section shows the evolution of the player's season-end rank over season
- The Game Length section shows the player's win rates in different game length brackets which is significant due to how the game is played over time (progressing from Feudal to Castle to Imperial age)- early gameplay is more micromanagement oriented and conversely late-game is more about macro
- The Opponents section is geographical represenation of the origin of the player's opponents
- The Insights section throws the entire payload of player data at `grok-4-fast-reasoning` with a custom prompt to extract patterns pertaning to the player's performance.

#### Leaderboard Statistics
- Shows a breakdown of countries for Conqueror (1400+ rating), Conqueror 3 (2000+ rating) and Top 100 players
- Shows the number of Conqueror players per million for all country populations
- Shows the average rank in each country

### Usage example

[Here is an example of a Pro Player's statistics](https://aoe4world.com/players/6924135-Hunyadi-Janos) are his player statistics. You can also try one of the other current top ladder players from the [current aoe4world leaderboard](https://aoe4world.com/leaderboard/rm_solo).


### Local Dev

To start your Phoenix server:

- Run `mix setup` to install and setup dependencies
- Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4001`](http://localhost:4001) from your browser.
