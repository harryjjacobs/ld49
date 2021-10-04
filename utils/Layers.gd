extends Node2D

var layer = []

func _ready():
    layer.append("")
    for i in range(1, 21):
        layer.append(ProjectSettings.get_setting("layer_names/2d_physics/layer_" + str(i)))


func get_layer(layer_name):
    return layer.find(layer_name)