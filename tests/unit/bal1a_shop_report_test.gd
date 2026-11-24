class_name Bal1aShopReportTest
extends GdUnitTestSuite
## BAL1-A: tools/shop_report.gd counts relics in first merchant stocks. Pure: the real Merchant.draw_stock over fixture seeds.

const ShopReport := preload("res://tools/shop_report.gd")


func before_test() -> void:
	CardDatabase.load_all()
	RelicDatabase.load_all()


func test_each_stock_holds_the_configured_relic_count() -> void:
	var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools("rogue"))
	var counts: Dictionary = ShopReport.count_stocks("rogue", 1, 40, ctx)
	assert_int(int(counts["_visits"])).is_equal(40)
	var total: int = 0
	for key: Variant in counts.keys():
		if String(key) != "_visits":
			total += int(counts[key])
	assert_int(total).is_equal(40 * int(MerchantConfig.block().get("relic_stock", 3)))


func test_the_report_is_repeatable_and_reads_shop_only_relics() -> void:
	var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools("wizard"))
	var first: Dictionary = ShopReport.count_stocks("wizard", 2, 60, ctx)
	var second: Dictionary = ShopReport.count_stocks("wizard", 2, 60, ctx)
	assert_dict(first).is_equal(second)
	var shop_only: int = 0
	for id: Variant in first.keys():
		if String(id) != "_visits" and Merchant.is_shop_only(RelicDatabase.get_relic(String(id))):
			shop_only += int(first[id])
	assert_bool(shop_only >= 60).is_true()  # at least the one reserved shop-only slot per visit
