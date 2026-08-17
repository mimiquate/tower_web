# TowerWeb

A Phoenix LiveView dashboard for viewing Tower events stored in TowerDB.

## Overview

TowerWeb provides a web interface to monitor error events captured by [Tower](https://github.com/mimiquate/tower) and persisted by [TowerDB](https://github.com/mimiquate/tower_db).

## Installation

First, install and configure [TowerDB](https://github.com/mimiquate/tower_db) following its installation guide.

Then add `tower_web` as a dependency in your `mix.exs`:

```elixir
def deps do
  [
    {:tower_web, "~> 0.4.0"}
  ]
end
```

## Setup

In your Phoenix router, import and mount the dashboard:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  import TowerWeb.Router

  scope "/" do
    pipe_through :browser
    tower_dashboard "/tower"
  end
end
```

## Usage

Start your Phoenix server and visit `/tower` to see the dashboard.

## License

See LICENSE file.
