class_name BossStagger
extends RefCounted
## Test helper (P-dodge 4c): turns the boss's phase-threshold stagger off in the loaded config (the Boss copies its
## definition when it is created, so call this before spawning it). Suites written before D16 pin the roar and the
## invulnerability right after a threshold hit; the stagger itself is covered in p_dodge_boss_test.gd.
## Reset with BossConfig.reset_cache() (those suites do it in after_test).


static func disable() -> void:
	((BossConfig.boss("boss_guardian")["transition"]) as Dictionary)["stagger"] = 0.0
