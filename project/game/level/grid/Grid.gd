class_name GridModel

# Profile.allow_mistakes is true and the user did an error
signal invalid_place_allowed()

static func must_be_implemented() -> Variant:
	assert(false, "Must be implemented")
	return null

class LineHint:
	var water_count: float
	var water_count_type: E.HintType
	var boat_count: int
	# On columns this must always be Any
	var boat_count_type: E.HintType
	func duplicate() -> LineHint:
		var h := LineHint.new()
		h.water_count = water_count
		h.water_count_type = water_count_type
		h.boat_count = boat_count
		h.boat_count_type = boat_count_type
		return h

class GridHints:
	# Total water in the grid
	var total_water: float
	# Total boats in the grid
	var total_boats: int
	# If a size is present here, exactly these many aquariums of this size must
	# exist in the solution. All other sizes are unrestricted.
	# Dictionary[float, int]
	var expected_aquariums: Dictionary

class WaterPosition:
	var i: int
	var j: int
	var loc: E.Waters
	func _init(i_: int, j_: int, loc_: E.Waters) -> void:
		i = i_
		j = j_
		loc = loc_
	static func from_ij2(grid: GridModel, oi: int, oj2: int) -> WaterPosition:
		var type := grid.get_cell(oi, oj2 / 2).cell_type()
		var corner := E.diag_to_corner(type, E.Side.Left if (oj2 & 1) == 0 else E.Side.Right)
		return WaterPosition.new(oi, oj2 / 2, E.corner_to_waters(corner, type))
	func to_vec3() -> Vector3i:
		return Vector3i(i, j, loc)
	func j2() -> int:
		match loc:
			E.Single, E.TopLeft, E.BottomLeft:
				return 2 * j
			_:
				return 2 * j + 1
	func to_ij2() -> Vector2i:
		return Vector2i(i, j2())

class CellHints:
	var adj_water_count: float
	var adj_water_count_type: E.HintType

class CellModel:
	func water_full() -> bool:
		return GridModel.must_be_implemented()
	# If full of water, all Corners return true
	func water_at(_corner: E.Corner) -> bool:
		return GridModel.must_be_implemented()
	# When user marks a tile definitely doesn't contain waters
	func nowater_full() -> bool:
		return GridModel.must_be_implemented()
	func noboat_full() -> bool:
		return GridModel.must_be_implemented()
	func noboatwater_full() -> bool:
		return GridModel.must_be_implemented()
	func nowater_at(_corner: E.Corner) -> bool:
		return GridModel.must_be_implemented()
	func noboat_at(_corner: E.Corner) -> bool:
		return GridModel.must_be_implemented()
	func nothing_full() -> bool:
		return GridModel.must_be_implemented()
	func nothing_at(_corner: E.Corner) -> bool:
		return GridModel.must_be_implemented()
	func block_full() -> bool:
		return GridModel.must_be_implemented()
	func block_at(_corner: E.Corner) -> bool:
		return GridModel.must_be_implemented()
	# Counts the sides of the grid as walls
	func wall_at(_wall: E.Walls) -> bool:
		return GridModel.must_be_implemented()
	# Puts water in the given diagonal and floods.
	# The flush_undo parameter tells if this change should be separate from the previous change
	# in the undo stack, useful for grouping multiple related changes in the same undo.
	# Returns whether it was a valid move
	func put_water(_corner: E.Corner, _flush_undo := true) -> float:
		return GridModel.must_be_implemented()
	# Puts nowater in the given diagonal
	func put_nowater(_corner: E.Corner, _flush_undo := true, _flood := false) -> bool:
		return GridModel.must_be_implemented()
	func put_noboat(_corner: E.Corner, _flush_undo := true) -> bool:
		return GridModel.must_be_implemented()
	func put_block(_corner: E.Corner, _flush_undo := true) -> bool:
		return GridModel.must_be_implemented()
	func remove_content(_corner: E.Corner, _flush_undo := true) -> void:
		return GridModel.must_be_implemented()
	func remove_nowater(_corner: E.Corner, _flush_undo := true) -> void:
		return GridModel.must_be_implemented()
	func remove_noboat(_corner: E.Corner, _flush_undo := true) -> void:
		return GridModel.must_be_implemented()
	func put_wall(_wall: E.Walls, _flush_undo := true, _unsafe_mode := false) -> bool:
		return GridModel.must_be_implemented()
	func remove_wall(_wall: E.Walls, _flush_undo := true) -> bool:
		return GridModel.must_be_implemented()
	func has_boat() -> bool:
		return GridModel.must_be_implemented()
	func put_boat(_flush_undo := true, _flood := false) -> bool:
		return GridModel.must_be_implemented()
	func cell_type() -> E.CellType:
		return GridModel.must_be_implemented()
	# Left then right
	func corners() -> Array[E.Corner]:
		return GridModel.must_be_implemented()
	func waters() -> Array[E.Waters]:
		return GridModel.must_be_implemented()
	func water_would_flood_how_many(_corner: E.Corner) -> float:
		return GridModel.must_be_implemented()
	func water_would_flood_which(_corner: E.Corner, _in_area: GridImpl.AreaCheck = null) -> Array[WaterPosition]:
		return GridModel.must_be_implemented()
	# Can this cell have a boat? (True if it already has one)
	func boat_possible(_disallow_nowater_below := true, _only_permanent_content := false) -> bool:
		return GridModel.must_be_implemented()
	# Returns only waters it would flood. Empty if boat not possible.
	func boat_would_flood_which() -> Array[WaterPosition]:
		return GridModel.must_be_implemented()
	func nowater_would_flood_how_many(_corner: E.Corner) -> float:
		return GridModel.must_be_implemented()
	# Returns if something changed
	func add_cell_hints(_flush_undo := true) -> bool:
		return GridModel.must_be_implemented()
	func rem_cell_hints(_flush_undo := true) -> bool:
		return GridModel.must_be_implemented()
	func hints() -> CellHints:
		return GridModel.must_be_implemented()
	func hints_status() -> E.HintStatus:
		return GridModel.must_be_implemented()

func rows() -> int:
	return GridModel.must_be_implemented()

func cols() -> int:
	return GridModel.must_be_implemented()

# 0-indexed
func get_cell(_i: int, _j: int) -> CellModel:
	return GridModel.must_be_implemented()

# Checks walls in the grid without accessing cells directly
func wall_at(_i: int, _j: int, _side: E.Side) -> bool:
	return GridModel.must_be_implemented()

# Tries to create walls from vertex 1 to vertex 2. Might be straight or diagonal.
# 0 <= i <= n
# 0 <= j <= m
# Might create multiple walls of the same type in a row.
# Returns whether the walls were created or were invalid
func put_wall_from_idx(_i1: int, _j1: int, _i2: int, _j2: int, _flush_undo := true) -> bool:
	return GridModel.must_be_implemented()

# Same as above but removes. Ignores walls that don't exist, returns false only if
# vertices are invalid.
func remove_wall_from_idx(_i1: int, _j1: int, _i2: int, _j2: int, _flush_undo := true) -> bool:
	return GridModel.must_be_implemented()

func row_hints() -> Array[LineHint]:
	return GridModel.must_be_implemented()

func col_hints() -> Array[LineHint]:
	return GridModel.must_be_implemented()

func add_row(_flush_undo := true) -> void:
	return GridModel.must_be_implemented()

func rem_row(_flush_undo := true) -> void:
	return GridModel.must_be_implemented()

func add_col(_flush_undo := true) -> void:
	return GridModel.must_be_implemented()

func rem_col(_flush_undo := true) -> void:
	return GridModel.must_be_implemented()

# How many boats are in the level
func get_expected_boats() -> int:
	return GridModel.must_be_implemented()

# How many waters are in the level
func get_expected_waters() -> float:
	return GridModel.must_be_implemented()

func all_boats_hint_status() -> E.HintStatus:
	return GridModel.must_be_implemented()

func all_waters_hint_status() -> E.HintStatus:
	return GridModel.must_be_implemented()

func all_hints_status() -> E.HintStatus:
	return GridModel.must_be_implemented()

# Is this a valid solution?
# If check_complete is true, it checks all cells are filled (even if with nowater)
func are_hints_satisfied(_check_complete := false) -> bool:
	return GridModel.must_be_implemented()

func is_any_hint_broken() -> bool:
	return GridModel.must_be_implemented()

func get_row_hint_status(_i : int, _hint_type : E.HintContent) -> E.HintStatus:
	return GridModel.must_be_implemented()

func get_col_hint_status(_j : int, _hint_type : E.HintContent) -> E.HintStatus:
	return GridModel.must_be_implemented()

func count_water_row(_i: int) -> float:
	return GridModel.must_be_implemented()

func count_water_col(_j: int) -> float:
	return GridModel.must_be_implemented()

func count_boat_row(_i: int) -> int:
	return GridModel.must_be_implemented()
	
func count_boat_col(_j: int) -> int:
	return GridModel.must_be_implemented()

func count_water_adj(_i: int, _j: int) -> float:
	return GridModel.must_be_implemented()

func count_nothing_adj(_i: int, _j: int) -> float:
	return GridModel.must_be_implemented()

func grid_hints() -> GridHints:
	return GridModel.must_be_implemented()

# Dictionary[float, int], the count of the sizes of each aquarium
func all_aquarium_counts() -> Dictionary:
	return GridModel.must_be_implemented()

# Whether all expected aquarium hints are satisfied.
func aquarium_hints_status() -> E.HintStatus:
	return GridModel.must_be_implemented()

enum LoadMode {
	# Default. Must be a solution, and the water/nowater/boats are cleared after loading and validation.
	Solution,
	# Same as above, but doesn't clear the contents.
	SolutionNoClear,
	# Doesn't need to be a solution. Rules auto-update. Useful for level editing.
	Editor,
	# For testing. Hints don't auto update.
	Testing,
	# Load only the content. Useful for loading from a user save file.
	ContentOnly,
}

# Replace this grid with the one loaded from the string
# Check LoadMode for how the string should be formatted in regard to the solution.
#
# The string should be a 2Nx2M grid, each cell represented by 4 characters
# 12
# 34
# 1 and 2 are the contents on both left and right sides.
# - w: water
# - x: nowater (not necessary for the solution, just for tracking where there's no water)
# - #: block (can't have either water or nowater)
# - .: nothing
# 3 is the left and bottom wall information.
# - |: left wall only
# - _: bottom wall only
# - L: bottom and left wall
# - .: no left or bottom walls
# 4 is the diagonal wall information.
# - ╲: major diagonal wall (fancy unicode ╲ to avoid escaping on strings)
# - /: minor diagonal wall
# - .: no diagonal wall
# If hints are desired, the string should be a (2N+1)x(2M+1) grid, and the first row and
# first column should contain the hints multiplied by two. The hints are integers, up to
# two characters long. (That's because hints in the actual game increment by 0.5)
# The other characters must be '.', and any row or column may not have a hint. (0, 0) should be 'h'
# (If the row hint has two characters, it must be one per line.)
# For boat hint, the same follows, but the (0,0) characted must be 'B'. And the hints aren't
# multiplied by two.
# Example:
# wwwx
# L../
# #..w
# L._╲
# Example with hints:
# h..1.3.
# 2......
# .|╲_/./
# 2......
# .L._.L.
#
# The string may begin with +key=value lines for extra data. The accept extra data is:
# - boats: total number of boats in the solution. Defaults to 0.
# - aqua: Hint for the water count of a aquarium that MUST be present. May be present
#   multiple times, but must be ordered.
func load_from_str(_s: String, _load_mode := LoadMode.Solution) -> void:
	return GridModel.must_be_implemented()

# Converts to string format as described on `load_from_str`
func to_str() -> String:
	return GridModel.must_be_implemented()

# Undo the latest changes. Returns true if it was possible to do so.
func undo(_skip_empty := true) -> bool:
	return GridModel.must_be_implemented()

# Redo the latest undone changes
func redo(_skip_empty := true) -> bool:
	return GridModel.must_be_implemented()

# Push empty undo. Only useful when doing multiple operations with flush = false
# It is safe to just have an empty undo, it will be ignored.
func push_empty_undo() -> void:
	return GridModel.must_be_implemented()

# Flood all water in the grid. Returns whether it did anything
func flood_all(_flush_undo := true) -> bool:
	return GridModel.must_be_implemented()

func flood_nowater(_flush_undo := true) -> bool:
	return GridModel.must_be_implemented()

# Clear all water and nowater
func clear_content() -> void:
	return GridModel.must_be_implemented()

# Same as clear_content on normal levels, but also clears walls on editor levels
func clear_all() -> void:
	return GridModel.must_be_implemented()

# Whether this allows editing walls and blocks
func editor_mode() -> bool:
	return GridModel.must_be_implemented()

func force_editor_mode(_b := true) -> void:
	return GridModel.must_be_implemented()

func set_auto_update_hints(_b: bool) -> void:
	return GridModel.must_be_implemented()

# Export data in a saveable way (dictionary with inner dictionaries and arrays)
func export_data() -> Dictionary:
	return GridModel.must_be_implemented()

# To import, use GridImpl.import_data

func is_empty() -> bool:
	return GridModel.must_be_implemented()

func copy_to_clipboard() -> void:
	return GridModel.must_be_implemented()

func merge_last_undo() -> void:
	return GridModel.must_be_implemented()

func count_waters() -> float:
	return GridModel.must_be_implemented()

func count_boats() -> int:
	return GridModel.must_be_implemented()

func count_blocks() -> float:
	return GridModel.must_be_implemented()

# If there are not boats, hide all boat hints
func prettify_hints(_is_procedurally_generated: bool) -> void:
	return GridModel.must_be_implemented()

# Is the grid fully filled, including s?
func check_complete() -> bool:
	return GridModel.must_be_implemented()

# Boats that may or may not be there, making the solution always Multiple
func any_schrodinger_boats() -> bool:
	return GridModel.must_be_implemented()

# Matches the stored solution
func is_equal_solution() -> bool:
	return GridModel.must_be_implemented()

func mirror_horizontal() -> void:
	return GridModel.must_be_implemented()

func mirror_vertical() -> void:
	return GridModel.must_be_implemented()

func rotate_clockwise() -> void:
	return GridModel.must_be_implemented()

func rotate_counter() -> void:
	return GridModel.must_be_implemented()
