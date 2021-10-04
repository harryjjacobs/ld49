tool
extends TileSet

const GROUND = 0
const DAMAGED_GROUND = 1

var binds = {
    GROUND: [DAMAGED_GROUND],
    DAMAGED_GROUND: [GROUND]
}

func _is_tile_bound(drawn_id, neighbor_id):
    if drawn_id in binds:
        return neighbor_id in binds[drawn_id]
    return false