shader_type spatial;

uniform float speed = 0.5;
uniform float turn_angle = 0.0;
uniform float concave_radius = 0.5;
uniform bool enable_demo_mode = false;
uniform sampler2D texture;

vec2 rotate(vec2 p, float angle)
{
	mat2 m = mat2(vec2(cos(angle), -sin(angle)),
				  vec2(sin(angle), cos(angle)));
	return m * p;
}

void vertex()
{
	if (abs(VERTEX.x) < concave_radius && abs(VERTEX.y) > concave_radius)
	{
		float dist = distance(VERTEX.xz, vec2(0.0, 0.0));
		VERTEX.y += sign(VERTEX.y)*(dist - concave_radius);
	}

	// Called for every vertex the material is visible on.
	float spin_speed = (2.0 * PI) * speed;
	float wheel_angle = turn_angle * (PI/180.0);
	enable_demo_mode ? spin_speed *= (TIME + cos(TIME)) : spin_speed *= TIME;
	VERTEX.xz = rotate(VERTEX.xz, spin_speed);
	VERTEX.yz = rotate(VERTEX.yz, wheel_angle);

	// Fix normal map so that lighting doesn't rotate with the wheel
	NORMAL.xz = rotate(NORMAL.xz, spin_speed);
}

void fragment()
{
	// Called for every pixel the material is visible on.
	vec3 new_texture = texture(texture, -UV).rgb;
	ALBEDO = new_texture;

	if (UV.y < 0.2)
	{
		if (mod(UV.x,0.2) < 0.1 && mod(UV.y,0.2) > 0.03)
		{
			ALBEDO = vec3(0.8,0.8,0.8);
		}
	}
	else if (UV.y > 0.8)
	{
		if (mod(UV.x,0.2) > 0.1 && mod(-UV.y,0.2) > 0.03)
		{
			ALBEDO = vec3(0.8,0.8,0.8);
		}
	}
}

// // void light()
// // {
// // 	// Called for every pixel for every light affecting the material.

// // }