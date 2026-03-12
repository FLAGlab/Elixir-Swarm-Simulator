# KnowledgeStore

**Módulo:** `Simulator.Algorithms.Helpers.KnowledgeStore`
**Archivo:** `lib/simulator/algorithms/helpers/knowledge_store.ex`

Utilidades para gestionar conocimiento compartido entre drones. Encapsula la lógica de
almacenamiento, decay, merge y exportación de posiciones recibidas de otros drones,
para que los algoritmos solo se ocupen de su estrategia de movimiento.

## Modelo de datos

El conocimiento se almacena como `%{source_pid => [positions]}`, donde cada entry está
atribuida al dron que originalmente exploró esas posiciones. Esta atribución por fuente:

- **Previene eco** — `merge/2` filtra `self()`, así que no almacenas tu propia data de vuelta
- **Evita duplicación** — la misma fuente siempre queda bajo la misma key
- **Permite transitividad** — si A comparte info de B, C la recibe atribuida a B (no a A)
- **Decae naturalmente** — `decay/1` elimina una posición por tick por entry

## Funciones públicas

### `decay(received_visited)`

Elimina la posición más vieja (última de la lista) de cada entry del conocimiento recibido.
Las entries que quedan vacías se descartan automáticamente.

```elixir
received = %{pid_a => [%{x: 1, y: 1}, %{x: 2, y: 2}, %{x: 3, y: 3}]}
KnowledgeStore.decay(received)
#=> %{pid_a => [%{x: 1, y: 1}, %{x: 2, y: 2}]}
```

**Cuándo llamar:** Una vez por tick, al inicio de `compute_step/1`, antes de usar el
conocimiento para tomar decisiones.

---

### `merge(received_visited, incoming_knowledge)`

Merge de conocimiento entrante con el almacenado. Aplica dos reglas:

1. **Anti-eco:** Filtra entries keyed por `self()` del incoming
2. **Frescura:** Por cada fuente, se queda con la lista más larga (más fresca)
   entre la existente y la entrante

```elixir
existing = %{pid_a => [%{x: 1, y: 1}]}
incoming = %{pid_a => [%{x: 1, y: 1}, %{x: 2, y: 2}], self() => [%{x: 3, y: 3}]}
KnowledgeStore.merge(existing, incoming)
#=> %{pid_a => [%{x: 1, y: 1}, %{x: 2, y: 2}]}  # self() filtrado, pid_a actualizado
```

**Cuándo llamar:** En `handle_received_data/3`, al recibir conocimiento de un vecino.

---

### `all_positions(visited, received_visited)`

Combina las posiciones propias del dron con todas las posiciones recibidas en una lista
plana. Útil para tener una visión unificada del conocimiento total.

```elixir
visited = [%{x: 1, y: 1}]
received = %{pid_a => [%{x: 2, y: 2}], pid_b => [%{x: 3, y: 3}]}
KnowledgeStore.all_positions(visited, received)
#=> [%{x: 1, y: 1}, %{x: 2, y: 2}, %{x: 3, y: 3}]
```

**Cuándo llamar:** En `compute_step/1`, para construir el mapa de calor o tomar
decisiones basadas en todo el conocimiento disponible.

---

### `build_shareable(visited, received_visited)`

Construye el mapa de conocimiento para broadcast. Incluye:
- Las posiciones propias del dron keyed por `self()`
- Todo el conocimiento recibido (para propagación transitiva)

```elixir
visited = [%{x: 1, y: 1}]
received = %{pid_b => [%{x: 2, y: 2}]}
KnowledgeStore.build_shareable(visited, received)
#=> %{self() => [%{x: 1, y: 1}], pid_b => [%{x: 2, y: 2}]}
```

**Cuándo llamar:** En `get_shared_data/1`, para armar el payload de broadcast.

---

### `format_for_export(algo_state)`

Prepara el estado del algoritmo para consumo externo (panel de detalle del dron).
Combina `:visited` y `:received_visited` en una sola lista `:visited` y elimina
`:received_visited`.

```elixir
algo_state = %{visited: [%{x: 1, y: 1}], received_visited: %{pid_a => [%{x: 2, y: 2}]}}
KnowledgeStore.format_for_export(algo_state)
#=> %{visited: [%{x: 1, y: 1}, %{x: 2, y: 2}]}
```

**Cuándo llamar:** En `format_state/1` del algoritmo.

## Algoritmos que lo usan

- **HeatmapWalk** — usa todas las funciones para compartir y gestionar posiciones visitadas
