#version 430

// Volumetric clouds: empty space skip map, built from the far weather map (begin_b.csh).
// Three levels of square tiles (1.6, 6.4 and 25.6 km at real scale) in one 256 x 336 image:
//   L1 256^2 at (x, y), L2 64^2 at (x, 256 + y), L3 16^2 at (x, 320 + y)
// x = min over the tile of (distance to the closest cloud - 0.29 km): > 0 means no low cloud,
// y = highest cloud top (km above CLOUD_ALTITUDE), w = highest mid layer field.
// The ray march crosses a whole tile in one step when it cannot meet a cloud in it.
// One work group per L3 tile, one thread per L1 tile, reductions in shared memory.

layout(local_size_x = 16, local_size_y = 16) in;

#include "/lib/Settings.inc"

#if defined VOLUMETRIC_CLOUDS && defined CLOUD_SKIP_MAP
const ivec3 workGroups = ivec3(16, 16, 1);
#else
const ivec3 workGroups = ivec3(1, 1, 1);
#endif

#include "/lib/clouds/CloudUniforms.inc"

layout(rgba16f) uniform writeonly image2D cloudSkip;

shared vec4 cloudSkipL1[256];
shared vec4 cloudSkipL2[16];

vec4 CloudSkipMerge(vec4 a, vec4 b) {
	return vec4(min(a.x, b.x), max(a.y, b.y), 0.0, max(a.w, b.w));
}

void main() {
	#if defined VOLUMETRIC_CLOUDS && defined CLOUD_SKIP_MAP
		ivec2 l1 = ivec2(gl_GlobalInvocationID.xy);
		uint li = gl_LocalInvocationIndex;
		ivec2 lid = ivec2(gl_LocalInvocationID.xy);

		// L1: 4 x 4 far weather texels (400 m each). The distance stored at a texel centre is
		// a lower bound at that point; anywhere in the texel it is at least 0.283 km less.
		vec4 v = vec4(1e4, -1e4, 0.0, -1e4);
		for (int y = 0; y < 4; y++)
		for (int x = 0; x < 4; x++) {
			vec4 w = texelFetch(cloudWeatherFarSampler, ivec3(l1 * 4 + ivec2(x, y), 1), 0);
			v = CloudSkipMerge(v, vec4(w.x - 0.29, w.z, 0.0, w.w));
		}
		imageStore(cloudSkip, l1, v);
		cloudSkipL1[li] = v;
		barrier();

		// L2: 4 x 4 L1 tiles
		if ((lid.x & 3) == 0 && (lid.y & 3) == 0) {
			vec4 m = vec4(1e4, -1e4, 0.0, -1e4);
			for (int y = 0; y < 4; y++)
			for (int x = 0; x < 4; x++) m = CloudSkipMerge(m, cloudSkipL1[(lid.y + y) * 16 + lid.x + x]);
			ivec2 l2 = l1 >> 2;
			imageStore(cloudSkip, ivec2(l2.x, 256 + l2.y), m);
			cloudSkipL2[(lid.y >> 2) * 4 + (lid.x >> 2)] = m;
		}
		barrier();

		// L3: the whole work group
		if (li == 0u) {
			vec4 m = vec4(1e4, -1e4, 0.0, -1e4);
			for (int i = 0; i < 16; i++) m = CloudSkipMerge(m, cloudSkipL2[i]);
			ivec2 l3 = ivec2(gl_WorkGroupID.xy);
			imageStore(cloudSkip, ivec2(l3.x, 320 + l3.y), m);
		}
	#endif
}
