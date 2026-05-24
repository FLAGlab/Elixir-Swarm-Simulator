defmodule Simulator.Maps.IndoorRoomsMap do
  @moduledoc """
  A 1200x600 indoor floor plan with rooms connected by a central hallway.

  Two rows of 5 rooms each (10 total) separated by a wide central corridor.
  Each room has a narrow doorway opening into the hallway. The spawn point
  is at the left end of the hallway.
  """

  @behaviour Simulator.Map

  alias Simulator.Maps.MapParams

  @impl true
  def get_parameters(_opts \\ %{}) do
    %MapParams{
      width: 1200,
      height: 600,
      spawn_point: %{x: 60, y: 300},
      structures: walls()
    }
  end

  # Private ----------------------------------------------------------

  # Each room is defined by its surrounding walls minus a doorway gap.
  # Rooms are 200w x 180h. Hallway runs y=230..370.
  # Top rooms: y=20..210, doorways at bottom wall (y=210).
  # Bottom rooms: y=390..580, doorways at top wall (y=390).

  defp walls do
    room_w = 200
    door_w = 40
    top_y1 = 20
    top_y2 = 210
    bot_y1 = 390
    bot_y2 = 580

    x_starts = [40, 260, 480, 700, 920]

    top_walls =
      x_starts
      |> Enum.with_index(1)
      |> Enum.flat_map(&room_walls(&1, room_w, door_w, top_y1, top_y2, :bottom))

    bot_walls =
      x_starts
      |> Enum.with_index(1)
      |> Enum.flat_map(&room_walls(&1, room_w, door_w, bot_y1, bot_y2, :top))

    # Hallway end caps (left and right walls of hallway)
    hallway_walls = [
      %{id: 100, points: [{0, 210}, {40, 210}, {40, 390}, {0, 390}]},
      %{id: 101, points: [{1120, 210}, {1200, 210}, {1200, 390}, {1120, 390}]}
    ]

    top_walls ++ bot_walls ++ hallway_walls
  end

  defp room_walls({x, room_num}, w, door_w, y1, y2, door_side) do
    x2 = x + w
    door_cx = x + div(w, 2)
    door_left = door_cx - div(door_w, 2)
    door_right = door_cx + div(door_w, 2)

    base_id = room_num * 10

    # Three solid walls + two segments for the wall with doorway
    {solid_walls, door_wall_segments} =
      case door_side do
        :bottom ->
          {
            [
              # Top wall
              %{id: base_id, points: [{x, y1}, {x2, y1}, {x2, y1 + 10}, {x, y1 + 10}]},
              # Left wall
              %{id: base_id + 1, points: [{x, y1}, {x + 10, y1}, {x + 10, y2}, {x, y2}]},
              # Right wall
              %{id: base_id + 2, points: [{x2 - 10, y1}, {x2, y1}, {x2, y2}, {x2 - 10, y2}]}
            ],
            [
              # Bottom wall left of door
              %{
                id: base_id + 3,
                points: [{x, y2 - 10}, {door_left, y2 - 10}, {door_left, y2}, {x, y2}]
              },
              # Bottom wall right of door
              %{
                id: base_id + 4,
                points: [{door_right, y2 - 10}, {x2, y2 - 10}, {x2, y2}, {door_right, y2}]
              }
            ]
          }

        :top ->
          {
            [
              # Bottom wall
              %{id: base_id, points: [{x, y2 - 10}, {x2, y2 - 10}, {x2, y2}, {x, y2}]},
              # Left wall
              %{id: base_id + 1, points: [{x, y1}, {x + 10, y1}, {x + 10, y2}, {x, y2}]},
              # Right wall
              %{id: base_id + 2, points: [{x2 - 10, y1}, {x2, y1}, {x2, y2}, {x2 - 10, y2}]}
            ],
            [
              # Top wall left of door
              %{
                id: base_id + 3,
                points: [{x, y1}, {door_left, y1}, {door_left, y1 + 10}, {x, y1 + 10}]
              },
              # Top wall right of door
              %{
                id: base_id + 4,
                points: [{door_right, y1}, {x2, y1}, {x2, y1 + 10}, {door_right, y1 + 10}]
              }
            ]
          }
      end

    solid_walls ++ door_wall_segments
  end
end
