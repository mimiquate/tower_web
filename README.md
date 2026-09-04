# TowerWeb

A Phoenix LiveView dashboard for viewing Tower events stored in TowerDB.

## Overview

TowerWeb provides a web interface to monitor error events captured by [Tower](https://github.com/mimiquate/tower) and persisted by [TowerDB](https://github.com/mimiquate/tower_db).

> [!WARNING]
> **Not production ready.** TowerWeb is under active development.  We use it in several applications at [Mimiquate](https://mimiquate.com), but it hasn't yet reached the bar we'd consider production ready. Use it at your own risk.
>
> Features we're waiting on before calling it production ready:
>
> - TowerDB production ready list
> - Performance test

## Installation

First, install and configure [TowerDB](https://github.com/mimiquate/tower_db) following its installation guide.

Then add `tower_web` as a dependency in your `mix.exs`:

```elixir
def deps do
  [
    {:tower_web, "~> 0.6.0"}
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
