shader_type canvas_item;

uniform vec2 center = vec2(0.5, 0.5);
uniform float radius = 0.5;
uniform float speed = 1.0;
uniform bool enable_demo_mode = false;

vec2 rotate(vec2 p, float angle)
{
	mat2 m = mat2(vec2(cos(angle), -sin(angle)),
					vec2(sin(angle), cos(angle)));

	return m * p;

}

void vertex() 
{
	// Called for every vertex the material is visible on.
}

void fragment() 
{
	// Called for every pixel the material is visible on.
	float dist = distance(UV, center);
	if (dist < radius)
	{
		float spin_speed = (2.0*PI) * speed;
		enable_demo_mode ? spin_speed *= TIME+cos(TIME) : spin_speed *= TIME;
		vec2 new_uv = rotate(UV-center, spin_speed);
		COLOR = texture(TEXTURE, new_uv+center);
	}
	else
	{
		COLOR.a = 0.0;
	}
	
}

//void light() 
//{
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
