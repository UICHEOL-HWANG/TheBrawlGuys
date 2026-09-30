extends GutTest
## Real HTTP transport: a request made while the host is still setting up its children (the web
## sign-in exchange during the app's _ready) must still start, and the result must arrive after
## the caller returns — never synchronously — so screens shown later still hear it.

const CLOSED_PORT_URL := "http://127.0.0.1:1/"


class BusyParent extends Node:
	var transport: GodotHttpTransport
	var results: Array = []

	func _ready() -> void:
		# Mirrors App._ready → LoginGate.restore(): request while the root adds this scene.
		transport.request(CLOSED_PORT_URL, PackedStringArray(), HTTPClient.METHOD_GET, "",
			func(status: int, _body: String) -> void: results.append(status))


func test_request_during_parent_setup_still_runs_and_reports_later() -> void:
	var host := Node.new()
	var busy := BusyParent.new()
	busy.transport = GodotHttpTransport.new(host)
	host.add_child(busy)
	add_child_autofree(host)  # host's children are being set up while busy._ready requests
	assert_eq(busy.results, [], "no synchronous result")
	await wait_until(func() -> bool: return busy.results.size() == 1, 5.0)
	assert_eq(busy.results, [0], "the refused connection is reported as status 0")


func test_result_never_arrives_synchronously() -> void:
	var host := Node.new()
	add_child_autofree(host)
	var results: Array = []
	GodotHttpTransport.new(host).request(CLOSED_PORT_URL, PackedStringArray(), HTTPClient.METHOD_GET, "",
		func(status: int, _body: String) -> void: results.append(status))
	assert_eq(results, [], "the caller returns before any result")
	await wait_until(func() -> bool: return results.size() == 1, 5.0)
	assert_eq(results, [0])


func test_gone_host_reports_failure_asynchronously() -> void:
	var host := Node.new()
	var results: Array = []
	var transport := GodotHttpTransport.new(host)
	host.free()
	transport.request(CLOSED_PORT_URL, PackedStringArray(), HTTPClient.METHOD_GET, "",
		func(status: int, _body: String) -> void: results.append(status))
	assert_eq(results, [])
	await wait_frames(2)
	assert_eq(results, [0])
