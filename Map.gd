extends Node2D

enum TileType { GROUND, LAVA }

class TileMapTileId:
	const GROUND_TILE_ID = 0
	const GROUND_BROKEN_TILE_ID = 1
	const LAVA_TILE_ID = 0
	const LAVA_WALL_TILE_ID = 1

class MapTile:
	var tilemap_pos: Vector2
	var initial_lifespan: float
	var lifespan_remaining: float
	func _init(p_tilemap_pos: Vector2, p_lifespan: float):
		tilemap_pos = p_tilemap_pos
		initial_lifespan = p_lifespan
		lifespan_remaining = p_lifespan

onready var _lava_tilemap = $LavaTileMap
onready var _ground_tilemap = $GroundTileMap

const _lava_splash_particles = preload("res://particles/LavaSplashParticles.tscn")
const _ground_collapse_particles = preload("res://particles/GroundCollapseParticles.tscn")

const _ground_tile_lifespan_at_spawn = 10.0
const _min_ground_tile_lifespan = 0.8
const _default_ground_tile_lifespan = 3.0
const _ground_tile_lifespan_variance = 0.4
# when remaining proportion of lifespan is below this, show visuals
const _ground_tile_remaining_lifespan_proportion_warning = 0.3

var _ground_tile_lifespan_modifier = 1.0
var _init_ground_state = []
var _overlay_ground_tilemap
var _overlay_lava_tilemap
var _last_update_area: Rect2
var _enabled = false
var _rng

var _map = {}

func _ready():
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_init_ground_state = _ground_tilemap.get_used_cells()

func init():
	_ground_tile_lifespan_modifier = 1.0
	_ground_tilemap.clear()
	_lava_tilemap.clear()
	for cell in _init_ground_state:
		_ground_tilemap.set_cellv(cell, TileMapTileId.GROUND_TILE_ID)
		_ground_tilemap.update_bitmask_area(cell)
	if _overlay_ground_tilemap:
		remove_child(_overlay_ground_tilemap)
	if _overlay_lava_tilemap:
		remove_child(_overlay_lava_tilemap)
	# initialise map from existing tilemap data
	_map = {}
	for cell in _lava_tilemap.get_used_cells():
		_map[cell] = MapTile.new(cell, 0)
	for cell in _ground_tilemap.get_used_cells():
		_map[cell] = MapTile.new(cell, _ground_tile_lifespan_at_spawn)
	_enabled = true

func generate_area(visible_area: Rect2):
	$DebugMapUpdateRect.rect_position = to_local(visible_area.position)
	$DebugMapUpdateRect.rect_size = visible_area.size
	
	var cell_size = _ground_tilemap.cell_size
	var terrain_gen = TerrainGen.new()
	var new_tile_positions = []
	for global_x in range(visible_area.position.x + cell_size.x / 2, visible_area.position.x + visible_area.size.x, cell_size.x):
		for global_y in range(visible_area.position.y + cell_size.y / 2, visible_area.position.y + visible_area.size.y,  cell_size.y):	
			var global_position = Vector2(global_x, global_y)
			var tilemap_position = _global_pos_to_tilemap_pos(global_position)
			if _map.has(tilemap_position):
				continue;
			if _ground_tilemap.get_cellv(tilemap_position) != TileMap.INVALID_CELL:
				continue
			new_tile_positions.push_back(tilemap_position)
			var tile_type = terrain_gen.get_tile_typev(tilemap_position)
			var tile_lifespan = 0
			match tile_type:
				TileType.GROUND:
					_ground_tilemap.set_cellv(tilemap_position, TileMapTileId.GROUND_TILE_ID)
					_ground_tilemap.update_bitmask_area(tilemap_position)
					var lifespan = _default_ground_tile_lifespan * _ground_tile_lifespan_modifier + \
							_ground_tile_lifespan_variance * _rng.randf_range(0, 1)
					tile_lifespan = max(_min_ground_tile_lifespan, lifespan)
					if _lava_tilemap.get_cellv(tilemap_position + Vector2.DOWN) == TileMapTileId.LAVA_TILE_ID:
						_lava_tilemap.set_cellv(tilemap_position + Vector2.DOWN, TileMapTileId.LAVA_WALL_TILE_ID)
				TileType.LAVA:
					if _ground_tilemap.get_cellv(tilemap_position + Vector2.UP) == TileMap.INVALID_CELL:
						_lava_tilemap.set_cellv(tilemap_position, TileMapTileId.LAVA_TILE_ID)
					else:
						_lava_tilemap.set_cellv(tilemap_position, TileMapTileId.LAVA_WALL_TILE_ID)
					_lava_tilemap.update_bitmask_area(tilemap_position)
			_map[tilemap_position] = MapTile.new(tilemap_position, tile_lifespan)
	_last_update_area = visible_area

	# generate lava layer


	# var global_region_start_position = Vector2(visible_area.position.x, visible_area.position.x + visible_area.size.x)
	# var global_region_end_position = Vector2(visible_area.position.y, visible_area.position.y + visible_area.size.y)
	# _ground_tilemap.update_bitmask_region(
	# 	_global_pos_to_tilemap_pos(global_region_start_position), 
	# 	_global_pos_to_tilemap_pos(global_region_end_position)
	# )
	# _ground_tilemap.get_used_cells()
	# _lava_tilemap.clear()

func overlay_ground_below_position(global_pos: Vector2):
	var tilemap_pos = _global_pos_to_tilemap_pos(global_pos)
	_overlay_lava_tilemap = _lava_tilemap.duplicate()
	_overlay_lava_tilemap.z_index = 1
	add_child(_overlay_lava_tilemap)
	_overlay_ground_tilemap = _ground_tilemap.duplicate()
	_overlay_ground_tilemap.z_index = 2
	add_child(_overlay_ground_tilemap)

	for cell in _lava_tilemap.get_used_cells():
		if cell.y <= tilemap_pos.y:
			_overlay_lava_tilemap.set_cellv(cell, -1)
	for cell in _ground_tilemap.get_used_cells():
		if cell.y < tilemap_pos.y:
			_overlay_ground_tilemap.set_cellv(cell, -1)

# between 0-1
func update_ground_lifespan_modifier(modifier):
	_ground_tile_lifespan_modifier = modifier

func stop_updating():
	_enabled = false

func _process(delta):
	if not _enabled:
		return
	for tile in _map.values():
		if _ground_tilemap.get_cellv(tile.tilemap_pos) != TileMap.INVALID_CELL:
			# TODO: show shake warning when tile is about to disapear
			if tile.lifespan_remaining <= 0:
				_collapse_ground_tile(tile.tilemap_pos)
			elif tile.lifespan_remaining / tile.initial_lifespan < _ground_tile_remaining_lifespan_proportion_warning:
				_ground_tilemap.set_cellv(tile.tilemap_pos, TileMapTileId.GROUND_BROKEN_TILE_ID)
				_ground_tilemap.update_bitmask_area(tile.tilemap_pos)
			tile.lifespan_remaining -= delta

func _collapse_ground_tile(position):
	_ground_tilemap.set_cellv(position, -1)
	if _lava_tilemap.get_cellv(position + Vector2.DOWN) == TileMapTileId.LAVA_WALL_TILE_ID:
		_lava_tilemap.set_cellv(position + Vector2.DOWN, TileMapTileId.LAVA_TILE_ID)	
	if _ground_tilemap.get_cellv(position + Vector2.UP) == TileMap.INVALID_CELL:
		_lava_tilemap.set_cellv(position, TileMapTileId.LAVA_TILE_ID)
	else:
		_lava_tilemap.set_cellv(position, TileMapTileId.LAVA_WALL_TILE_ID)
	var ground_particles = _ground_collapse_particles.instance()
	add_child(ground_particles)
	ground_particles.position = to_local(_lava_tilemap.map_to_world(position)) + _lava_tilemap.cell_size / 2
	ground_particles.emitting = true
	yield(get_tree().create_timer(0.1), "timeout")
	var lava_particles = _lava_splash_particles.instance()
	add_child(lava_particles)
	lava_particles.position = to_local(_lava_tilemap.map_to_world(position)) + _lava_tilemap.cell_size / 2
	lava_particles.emitting = true
	# hack
	yield(get_tree().create_timer(5), "timeout")
	remove_child(ground_particles)
	remove_child(lava_particles)

func _global_pos_to_tilemap_pos(global_position: Vector2):
	var local_position = _ground_tilemap.to_local(global_position)
	return _ground_tilemap.world_to_map(local_position)

class TerrainGen:
	var _saturation = 0.45
	var _noise = OpenSimplexNoise.new()
	func _init():
		_noise.seed = randi()
		_noise.octaves = 4
		_noise.period = 20.0
		_noise.persistence = 0.8

	func get_tile_typev(position: Vector2):
		var value = (_noise.get_noise_2dv(position) + 1) / 2
		if value < _saturation:
			return TileType.LAVA
		else:
			return TileType.GROUND

	func get_tile_types_for_area(positions: Array):
		var tile_types = Array()
		tile_types.resize(len(positions))
		for i in range(len(positions)):
			tile_types[i] = get_tile_typev(positions[i])
		return tile_types
