class_name CardDatabaseTest
extends GdUnitTestSuite
## Only exercises CardDatabase's happy path (valid fixtures). Malformed-data
## handling is covered by card_schema_test.gd against CardSchema directly,
## since CardDatabase's error path intentionally push_error()s - doing that
## inside a test risks tripping gdUnit4's own error monitor. See
## docs/DECISIONS.md.

const FIXTURES_DIR := "res://tests/fixtures/cards_valid"


func before_test() -> void:
	CardDatabase.load_all(FIXTURES_DIR)


func test_loads_every_valid_fixture() -> void:
	assert_int(CardDatabase.all_cards().size()).is_equal(2)


func test_get_card_by_id() -> void:
	var card := CardDatabase.get_card("test_quick_slash")
	assert_str(card.get("name", "")).is_equal("Quick, I Guess")


func test_has_card() -> void:
	assert_bool(CardDatabase.has_card("test_quick_slash")).is_true()
	assert_bool(CardDatabase.has_card("not_a_real_card")).is_false()


func test_cards_for_pool() -> void:
	var rogue_cards := CardDatabase.cards_for_pool("rogue")
	assert_int(rogue_cards.size()).is_equal(1)


func test_cards_for_slot_type() -> void:
	var recovery_cards := CardDatabase.cards_for_slot_type("recovery")
	assert_int(recovery_cards.size()).is_equal(1)
