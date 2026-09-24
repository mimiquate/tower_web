# TowerWeb

A Phoenix LiveView dashboard for viewing and storing Tower events.

## Overview

TowerWeb provides a web interface to monitor error events captured by [Tower](https://github.com/mimiquate/tower), and includes its own Ecto-backed reporter to persist those events to a PostgreSQL database — no separate storage package required.

> [!IMPORTANT]
> **[`tower_db`](https://github.com/mimiquate/tower_db) is being deprecated in favor of this built-in storage.** If your app currently depends on `tower_db`, migrate to `tower_web`'s own storage and remove the `tower_db` dependency — see [Migrating from `tower_db`](#migrating-from-tower_db) below. New installs should skip `tower_db` entirely.

> [!WARNING]
> **Not production ready.** TowerWeb is under active development.  We use it in several applications at [Mimiquate](https://mimiquate.com), but it hasn't yet reached the bar we'd consider production ready. Use it at your own risk.
>
> Features we're waiting on before calling it production ready:
>
> - Performance test

## Installation

Add `tower_web` as a dependency in your `mix.exs`:

```elixir
def deps do
  [
    {:tower_web, "~> 0.8.0"}
  ]
end
```

## Setup

### 1. Configure the reporter

Register `TowerWeb.DB` as a Tower reporter, and point it at your application's Ecto repo:

```elixir
config :tower, :reporters, [TowerWeb.DB]
```

```elixir
# runtime.exs
config :tower_web, enabled: true, repo: MyApp.Repo
```

### 2. Add and run the migration

Generate a migration:

```
mix ecto.gen.migration add_tower_web_db
```

Fill it with:

```elixir
defmodule MyApp.Repo.Migrations.AddTowerWebDB do
  use Ecto.Migration

  def up, do: TowerWeb.DB.Migration.up(from: 0, to: 9)
  def down, do: TowerWeb.DB.Migration.down(from: 9, to: 0)
end
```

Then run:

```
mix ecto.migrate
```

### 3. Mount the dashboard

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

## Migrating from `tower_db`

If your app already depends on the standalone [`tower_db`](https://github.com/mimiquate/tower_db) package, move to `tower_web`'s built-in storage instead of running both:

1. Follow [Setup](#setup) above, but for step 2, run only the new migration step that renames your existing `tower_db_events` table in place (all data is preserved):

   ```elixir
   defmodule MyApp.Repo.Migrations.AddTowerWebDB do
     use Ecto.Migration

     def up, do: TowerWeb.DB.Migration.up(from: 8, to: 9)
     def down, do: TowerWeb.DB.Migration.down(from: 9, to: 8)
   end
   ```

2. Replace `TowerDB` with `TowerWeb.DB` everywhere it's referenced in your app: `config :tower, :reporters, [...]`, any `config :tower_db, ...` keys (move them to `config :tower_web, ...`), and any direct calls like `TowerDB.Reporter.report_event/1`.
3. Remove `{:tower_db, ...}` from your `mix.exs` deps.

Don't keep both `tower_db` and `tower_web` installed and enabled long-term — that leaves you with two independent tables (`tower_db_events` and `tower_web_events`) and two reporters that could both persist the same event. `tower_db` is going away; `tower_web` is the path forward.

## Configuration

### Pruner

TowerWeb periodically prunes old events so the table doesn't grow unbounded. Configure it with:

```elixir
config :tower_web,
  pruner: [
    max_age: {90, :days},
    max_size: 100_000,
    max_size_per_issue: 1_000,
    interval: {30, :seconds},
    batch_size: 1_000
  ]
```

Set `pruner: false` to disable it entirely.

### Enable/disable at runtime

```elixir
TowerWeb.DB.enable()
TowerWeb.DB.disable()
```

## Usage

Start your Phoenix server and visit `/tower` to see the dashboard.

## License

See LICENSE file.
