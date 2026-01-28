defmodule SimulatorWeb.SimulationControllerTest do
  use SimulatorWeb.ConnCase

  import Simulator.SimulationsFixtures

  @create_attrs %{type: "some type", algorithm: "some algorithm", swarm: 42}
  @update_attrs %{type: "some updated type", algorithm: "some updated algorithm", swarm: 43}
  @invalid_attrs %{type: nil, algorithm: nil, swarm: nil}

  describe "index" do
    test "lists all simulations", %{conn: conn} do
      conn = get(conn, ~p"/simulations")
      assert html_response(conn, 200) =~ "Listing Simulations"
    end
  end

  describe "new simulation" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/simulations/new")
      assert html_response(conn, 200) =~ "New Simulation"
    end
  end

  describe "create simulation" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/simulations", simulation: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/simulations/#{id}"

      conn = get(conn, ~p"/simulations/#{id}")
      assert html_response(conn, 200) =~ "Simulation #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/simulations", simulation: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Simulation"
    end
  end

  describe "edit simulation" do
    setup [:create_simulation]

    test "renders form for editing chosen simulation", %{conn: conn, simulation: simulation} do
      conn = get(conn, ~p"/simulations/#{simulation}/edit")
      assert html_response(conn, 200) =~ "Edit Simulation"
    end
  end

  describe "update simulation" do
    setup [:create_simulation]

    test "redirects when data is valid", %{conn: conn, simulation: simulation} do
      conn = put(conn, ~p"/simulations/#{simulation}", simulation: @update_attrs)
      assert redirected_to(conn) == ~p"/simulations/#{simulation}"

      conn = get(conn, ~p"/simulations/#{simulation}")
      assert html_response(conn, 200) =~ "some updated type"
    end

    test "renders errors when data is invalid", %{conn: conn, simulation: simulation} do
      conn = put(conn, ~p"/simulations/#{simulation}", simulation: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Simulation"
    end
  end

  describe "delete simulation" do
    setup [:create_simulation]

    test "deletes chosen simulation", %{conn: conn, simulation: simulation} do
      conn = delete(conn, ~p"/simulations/#{simulation}")
      assert redirected_to(conn) == ~p"/simulations"

      assert_error_sent 404, fn ->
        get(conn, ~p"/simulations/#{simulation}")
      end
    end
  end

  defp create_simulation(_) do
    simulation = simulation_fixture()

    %{simulation: simulation}
  end
end
