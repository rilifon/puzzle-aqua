class_name DumbMutex
# Very simple mutex, which is async and not reentrant (important!)
# Should be used only on async contexts

var locked := false
var last_lock := 0

func lock() -> void:
	while locked:
		await Global.wait(0.1)
		if last_lock - Time.get_ticks_msec() > 5000:
			push_error("We probably fucked up the mutex, letting it through.")
			break
	locked = true
	last_lock = Time.get_ticks_msec()

func unlock() -> void:
	assert(locked)
	locked = false
