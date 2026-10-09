
//Packing functions
float PackTwo8BitTo16Bit(float a, float b)
{
	float data;
	vec2 v=vec2(a,b);

	v = clamp(v, 0.0, 255.0 / 256.0);
	v = floor(v * 255.0);

	data = v.x * 256.0 + v.y;
	data /= 65535.0;

	return data;
}

vec2 UnpackTwo8BitFrom16Bit(float value)
{
	vec2 data;

	value *= 65535.0;

	data.x = floor(value / 256.0);
	data.y = mod(value, 256.0);

	data /= 255.0;

	return data;
}





float PackTwo16BitTo32Bit(float a, float b) {
	vec2 v = vec2(a, b);
    return dot(floor(v*8191.9999),vec2(1./8192.,1.));
}
vec2 UnpackTwo16BitFrom32Bit(float v) {
    return vec2(fract(v)*(8192./8191.),floor(v)/8191.);
}
