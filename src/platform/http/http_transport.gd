class_name HttpTransport
extends RefCounted
## HTTP seam for platform clients (Amplitude, Supabase). Production uses GodotHttpTransport;
## tests inject a fake so no test touches the network.
## done is called once with (status: int, body: String); status 0 means no HTTP response.


func request(_url: String, _headers: PackedStringArray, _method: HTTPClient.Method, _body: String,
		done: Callable) -> void:
	push_error("HttpTransport.request is abstract")
	done.call(0, "")
