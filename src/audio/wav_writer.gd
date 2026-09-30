class_name WavWriter
extends RefCounted
## Float samples -> 16-bit mono AudioStreamWAV (saved with save_to_wav by the bake scripts).

const FULL_SCALE := 32767.0


static func to_stream(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		data.encode_s16(i * 2, roundi(clampf(samples[i], -1.0, 1.0) * FULL_SCALE))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream
