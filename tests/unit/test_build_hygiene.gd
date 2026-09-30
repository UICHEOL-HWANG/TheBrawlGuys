extends GutTest
## build/ lives under res://, so Godot would import and pack its output without a .gdignore.


func test_build_dir_is_hidden_from_the_importer() -> void:
	assert_true(FileAccess.file_exists("res://build/.gdignore"), "build/.gdignore keeps exports out of the import and the pck")


func test_build_script_guarantees_the_gdignore() -> void:
	var text := FileAccess.get_file_as_string("res://scripts/build_all.sh")
	assert_true(text.contains(".gdignore"), "build_all.sh recreates it")
