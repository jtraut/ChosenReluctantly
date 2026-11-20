class_name Tl2WatchModeTest
extends GdUnitTestSuite
## TL2: the pure half of watch-the-bot mode (argument parsing, shot file names, log wording).


func test_parse_dir_reads_the_flag() -> void:
	assert_str(WatchMode.parse_dir(["--run", "--watch-shots=C:/shots/m3"])).is_equal("C:/shots/m3")
	assert_str(WatchMode.parse_dir(["--run"])).is_empty()
	assert_bool(WatchMode.is_bare(["--watch-shots="])).is_true()
	assert_bool(WatchMode.is_bare(["--watch-shots=x"])).is_false()
	assert_bool(WatchMode.is_bare(["--seed=1"])).is_false()


func test_slug_keeps_words_and_collapses_the_rest() -> void:
	assert_str(WatchMode.slug("Choice: Relic / Boss!")).is_equal("choice-relic-boss")
	assert_str(WatchMode.slug("--x--")).is_equal("x")
	assert_str(WatchMode.slug("")).is_empty()


func test_shot_path_is_numbered_in_a_run_folder() -> void:
	assert_str(WatchMode.shot_path("out/", "Rogue", 7, 3, "map pick")).is_equal("out/rogue-seed7/03-map-pick.png")
	assert_str(WatchMode.shot_path("out", "wizard", 2, 0, "crowded-fight")).is_equal("out/wizard-seed2/crowded-fight.png")
	assert_str(WatchMode.shot_path("out", "wizard", 2, 12, "???")).is_equal("out/wizard-seed2/12-shot.png")


func test_option_and_offers_text() -> void:
	assert_str(WatchMode.option_text({"id": "card:a", "label": "Ember", "enabled": true})).is_equal("card:a (Ember)")
	assert_str(WatchMode.option_text({"id": "skip", "enabled": false})).is_equal("skip [locked]")
	assert_str(WatchMode.offers_text([{"id": "a", "label": "A"}, {"id": "b"}])).is_equal("a (A); b")


func test_deck_text_counts_in_first_seen_order() -> void:
	var deck: Array[String] = ["x", "y", "x", "z"]
	assert_str(WatchMode.deck_text(deck, {"x": "Ex", "y": "Why"})).is_equal("Ex x2, Why, z")
