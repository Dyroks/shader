#include "/lib/Uniforms.inc"


in vec4 texcoord;


void main() {

	#ifdef MOTION_BLUR

	vec2 maxVelocity = (texture2DLod(colortex2, texcoord.xy, 0).xy * 2.0 - 1.0);
	float maxLen = 0.0;

	if (texcoord.x < 1.0 / 16.0 && texcoord.y < 1.0 / 16.0)
	{
		for (int i = -2; i <= 2; i++)
		{
			for (int j = -2; j <= 2; j++)
			{
				vec2 coord = texcoord.xy + vec2(i, j) * ScreenTexel;

				coord = clamp(coord, vec2(0.0), vec2(1.0 / 16.0));

				vec2 vel = texture2DLod(colortex2, coord, 0).xy * 2.0 - 1.0;
				float len = length(vel);

				if (len > maxLen && abs(dot(normalize(vec2(i, j)), normalize(vel))) > 0.9 && len > length(vec2(i, j)) * 0.1)
				{
					maxLen = len;
					maxVelocity = vel;
				}
			}
		}
	}

	gl_FragData[0] = texture2DLod(colortex6, texcoord.xy, 0);
	gl_FragData[1] = vec4(maxVelocity * 0.5 + 0.5, 0.0, 1.0);
	#else
	gl_FragData[0] = texture2DLod(colortex6, texcoord.xy, 0);
	gl_FragData[1] = texture2DLod(colortex2, texcoord.xy, 0);
	#endif
}

/* DRAWBUFFERS:12 */
