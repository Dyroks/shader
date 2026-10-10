// =====================================================================================
//  GI module: rays through the voxel volume
//
//  GiTraceRay walks the voxels along a ray (3D DDA) up to the first surface:
//   - a short inner loop skips the empty voxels; the block shape test and the texture
//     lookups run once per non empty voxel (the threads of a warp do not wait on one
//     another's shape tests at every step),
//   - glass and stained glass let the ray through (stained glass tints it), alpha tested
//     textures (leaves, plants) let it through their transparent texels,
//   - a small light voxel (torch, lantern) stops the ray like an emitting cube, except the
//     one holding the ray origin (a surface next to a torch): its light is added and the
//     ray goes on.
//  The ray escapes (sky) when it leaves the volume or after maxSteps voxels.
//
//  This is the only place that knows how the voxels are stored: a hardware ray tracing
//  version only has to provide the same GiTraceRay.
//
//  Needs GiVolume.glsl, Ray / MakeRay, and the block shape test of the pack
//  (BlockShapes_*.glsl, from SEUS: to be replaced). Uniforms: shadowcolor, shadowcolor1,
//  colortex3 (block atlas in the deferred passes), depthtex0 (specular atlas).
// =====================================================================================

#ifndef GI_TRACE_INC
#define GI_TRACE_INC

struct GiHit {
	bool  escaped;        // left the volume or ran out of steps: sky light
	int   id;             // voxel id of the surface hit
	ivec3 voxel;          // volume coordinates of the voxel hit
	float dist;           // distance along the ray, in blocks (10000 when escaped)
	vec3  normal;         // normal of the face hit (against the ray)
	vec3  albedo;         // surface colour (texture x biome tint), 1 for the face lights
	vec3  emission;       // light emitted by the surface (before the transmittance)
	vec3  transmittance;  // stained glass crossed before the hit
	vec3  originLight;    // light of a small light voxel holding the ray origin
	vec3  specular;       // smoothness, metalness, emissive of the surface (specular maps)
};

// Block shape test (SEUS, BlockShapes_*.glsl): true when the ray hits the shape of block id
// in the voxel before t; t and n then hold the hit
bool GiShapeHit(vec3 voxel, int id, Ray ray, inout float t, inout vec3 n) {
	return c(voxel, float(id), ray, t, n);
}

// Entry of the ray into a voxel cube
void GiCubeEntry(vec3 voxel, Ray ray, out float t, out vec3 n) {
	vec3 t0 = (voxel - ray.origin) * ray.inv_direction;
	vec3 t1 = (voxel + 1.0 - ray.origin) * ray.inv_direction;
	vec3 tNear = min(t0, t1);
	t = max(max(tNear.x, tNear.y), max(tNear.z, 0.0));
	n = -step(vec3(t), tNear) * sign(ray.direction);
}

// Colour of the face hit at the hit point, from the block atlas
vec4 GiSurfaceTexel(Ray ray, float t, vec3 n, ivec2 texel, out vec3 specular, out float tint) {
	vec3 local = fract(ray.origin + ray.direction * t) - 0.5;
	vec2 offset = vec2(local.z * -n.x, -local.y) * abs(n.x)
	            + vec2(local.x, local.z * n.y) * abs(n.y)
	            + vec2(local.x * n.z, -local.y) * abs(n.z);
	vec4 coordData = texelFetch(shadowcolor1, texel, 0);
	float textureResolution = TEXTURE_RESOLUTION;
	#if TEXTURE_RESOLUTION == 0
		textureResolution = exp2(coordData.w * 255.0);
	#endif
	vec2 tiles = vec2(textureSize(colortex3, 0)) / textureResolution;
	vec2 uv = (floor(coordData.xy * tiles) + 0.5 + offset) / tiles;
	vec4 color = textureLod(colortex3, uv, 0.0);
	color.rgb = pow(color.rgb, vec3(2.2));
	tint = coordData.z;
	specular = vec3(0.0);
	#ifdef MC_SPECULAR_MAP
		vec4 s = textureLod(depthtex0, uv, 0.0);
		specular = vec3(s[SPEC_CHANNEL_SMOOTHNESS], s[SPEC_CHANNEL_METALNESS], s[SPEC_CHANNEL_EMISSIVE]);
		#if SPEC_CHANNEL_EMISSIVE == 3
			specular.z -= step(1.0, specular.z);
		#endif
	#endif
	return color;
}

GiHit GiTraceRay(vec3 origin, vec3 dir, int maxSteps) {
	GiHit hit;
	hit.escaped = true;
	hit.id = giIdEmpty;
	hit.voxel = ivec3(0);
	hit.dist = 10000.0;
	hit.normal = -dir;
	hit.albedo = vec3(1.0);
	hit.emission = vec3(0.0);
	hit.transmittance = vec3(1.0);
	hit.originLight = vec3(0.0);
	hit.specular = vec3(0.0);

	Ray ray = MakeRay(origin, dir);
	ivec3 voxel = ivec3(floor(origin));
	vec3 stepSign = sign(dir);
	vec3 tDelta = abs(1.0 / (dir + 1e-7));
	vec3 tMax = (stepSign * (floor(origin) - origin) + stepSign * 0.5 + 0.5) * tDelta;
	vec3 stepMask = vec3(0.0);   // axis crossed to reach the next voxel (none for the origin voxel)
	int prevId = giIdEmpty;
	int s = 0;

	while (true) {
		bool found = false;
		int id = giIdEmpty;
		ivec2 texel;
		vec4 vox;
		for (; s < maxSteps; s++) {
			voxel += ivec3(stepMask * stepSign);
			if (!GiInVolume(voxel)) break;
			texel = GiVoxelTexel(voxel);
			vox = texelFetch(shadowcolor, texel, 0);
			stepMask = step(tMax, vec3(min(tMax.x, min(tMax.y, tMax.z))));
			tMax += stepMask * tDelta;
			id = int(vox.a * 255.0 + 0.5);
			if (id != giIdEmpty) {
				found = true;
				break;
			}
			prevId = id;
		}
		if (!found) break;

		if (id == giIdSmallLight) {
			if (s == 0) {
				// the surface sits next to the light: always lit by it
				hit.originLight += vox.rgb * (0.0625 * GI_LIGHT_TORCH_INTENSITY);
				prevId = id;
				s++;
				continue;
			}
			hit.escaped = false;
			hit.id = id;
			hit.voxel = voxel;
			GiCubeEntry(vec3(voxel), ray, hit.dist, hit.normal);
			hit.albedo = vec3(0.0);
			hit.emission = vox.rgb * (0.125 * GI_LIGHT_TORCH_INTENSITY);
			break;
		}

		// only the first voxel of a glass pane is tested
		bool glass = id == giIdStainedGlass || id == giIdGlass;
		float t = 10000.0;
		vec3 n = vec3(0.0);
		if ((glass && prevId == id) || !GiShapeHit(vec3(voxel), id, ray, t, n)) {
			prevId = id;
			s++;
			continue;
		}

		if (id >= giIdFaceLightFirst && id <= giIdFaceLightLast) {
			// lit furnace: light toward its front face only, no texture lookup
			float facing = id == 32 ? -n.z : id == 33 ? n.x : id == 34 ? n.z : -n.x;
			hit.escaped = false;
			hit.id = id;
			hit.voxel = voxel;
			hit.dist = t;
			hit.normal = n;
			hit.emission = 0.1 * max(facing, 0.0) * vec3(2.0, 0.35, 0.025) * GI_LIGHT_BLOCK_INTENSITY;
			break;
		}

		vec3 specular;
		float tint;
		vec4 color = GiSurfaceTexel(ray, t, n, texel, specular, tint);
		bool alphaTested = id >= giIdAlphaTestFirst && id <= giIdAlphaTestLast;
		if (color.a > 0.999 || !alphaTested) {
			hit.escaped = false;
			hit.id = id;
			hit.voxel = voxel;
			hit.dist = t;
			hit.normal = n;
			hit.albedo = color.rgb * mix(vec3(1.0), vox.rgb, tint);
			hit.specular = specular;
			#ifdef SPEC_EMISSIVE
			if (specular.z > 0.0)
				hit.emission = 0.1 * hit.albedo * GI_LIGHT_BLOCK_INTENSITY * specular.z;
			else
			#endif
			if (id == giIdLightBlock)
				hit.emission = 0.1 * hit.albedo * GI_LIGHT_BLOCK_INTENSITY;
			else if (id == giIdRedLight) {
				float red = giSat(hit.albedo.r - (hit.albedo.g + hit.albedo.b) * 0.5 - 0.3);
				hit.emission = 0.1 * hit.albedo * GI_LIGHT_BLOCK_INTENSITY * vec3(2.0, 0.35, 0.025) * step(1e-5, red);
			}
			break;
		}
		if (id == giIdStainedGlass) {
			// transparent texel of stained glass: tints the ray
			vec3 c = normalize(color.rgb + 1e-4) * pow(dot(color.rgb, color.rgb), 0.25);
			c = mix(vec3(1.0), c, pow(color.a, 0.2));
			hit.transmittance *= c * c;
		}
		prevId = id;
		s++;
	}
	return hit;
}

#endif
