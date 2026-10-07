class_name SfxMix
extends RefCounted
## Layered sound recipes (design.md DS-SFX-01): {"volume", "layers": [SfxSynth recipe + "delay"
## (seconds) + "gain"]} sums each layer, offset by its delay, and peak-normalizes the mix to
## `volume`. A recipe without "layers" is a plain SfxSynth recipe. Offline only (bake_sfx.gd).

const DEFAULT_VOLUME := 0.8


static func render(recipe: Dictionary) -> PackedFloat32Array:
	if not recipe.has("layers"):
		return SfxSynth.render(recipe)
	var out := PackedFloat32Array()
	for layer: Dictionary in recipe["layers"]:
		var start := roundi(float(layer.get("delay", 0.0)) * SfxSynth.SAMPLE_RATE)
		var gain := float(layer.get("gain", 1.0))
		var s := SfxSynth.render(layer)
		if out.size() < start + s.size():
			out.resize(start + s.size())  # new samples are 0.0
		for i: int in s.size():
			out[start + i] += s[i] * gain
	var pk := SfxSynth.peak(out)
	if pk > 0.0:
		var g := float(recipe.get("volume", DEFAULT_VOLUME)) / pk
		for i: int in out.size():
			out[i] *= g
	return out
