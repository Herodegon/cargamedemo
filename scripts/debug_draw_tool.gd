extends Node

func line(pos1: Vector3, pos2: Vector3, color: Color = Color.WHITE_SMOKE) -> MeshInstance3D:
    var line_instance := MeshInstance3D.new()
    var line_mesh := ImmediateMesh.new()
    var material := ORMMaterial3D.new()

    line_instance.mesh = line_mesh
    line_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    line_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
    line_mesh.surface_add_vertex(pos1)
    line_mesh.surface_add_vertex(pos2)
    line_mesh.surface_end()

    material.depth_draw_mode = ORMMaterial3D.DEPTH_DRAW_DISABLED
    material.shading_mode = ORMMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = color

    get_tree().get_root().add_child(line_instance)

    return line_instance