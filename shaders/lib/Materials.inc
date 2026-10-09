#define MAT_ID_OPAQUE 1
#define MAT_ID_GRASS 2
#define MAT_ID_LEAVES 3
#define MAT_ID_HAND 4
#define MAT_ID_ENTITY_PLAYER 5
#define MAT_ID_WATER 6
#define MAT_ID_STAINED_GLASS 7
#define MAT_ID_ICE 8
#define MAT_ID_TORCH 30
#define MAT_ID_LAVA 31
#define MAT_ID_GLOWSTONE 32
#define MAT_ID_FIRE 33
#define MAT_ID_LIT_FURNACE 34
#define MAT_ID_DYNAMIC_ENTITY 35
#define MAT_ID_BEACON 36
#define MAT_ID_GLOW_LICHEN 37
#define MAT_ID_GLOW_BERRIES 38



struct MaterialMask
{
	float sky;
	float opaque;
	float grass;
	float leaves;
	float hand;
	float entityPlayer;
	float water;
	float stainedGlass;
	float ice;
	float torch;
	float lava;
	float glowstone;
	float fire;
	float litFurnace;
	float beacon;
	float glowLichen;
	float glowBerries;
};


float GetMaterialMask(const in int ID, in float matID)
{
	//Catch last part of sky
	matID *= step(matID, 254.0f);

	return float(matID == ID);
}

MaterialMask CalculateMasks(float materialID, vec2 coord)
{
	MaterialMask frnQIYJjVJ;

	materialID *= 255.0;

	frnQIYJjVJ.sky = step(0.999999, textureLod(depthtex1, coord.st, 0.0).x);

	frnQIYJjVJ.opaque 		= GetMaterialMask(MAT_ID_OPAQUE, materialID);
	frnQIYJjVJ.grass 		= GetMaterialMask(MAT_ID_GRASS, materialID);
	frnQIYJjVJ.leaves 		= GetMaterialMask(MAT_ID_LEAVES, materialID);
	frnQIYJjVJ.hand 		= GetMaterialMask(MAT_ID_HAND, materialID);
	frnQIYJjVJ.entityPlayer = GetMaterialMask(MAT_ID_ENTITY_PLAYER, materialID);
	frnQIYJjVJ.water 		= GetMaterialMask(MAT_ID_WATER, materialID);
	frnQIYJjVJ.stainedGlass	= GetMaterialMask(MAT_ID_STAINED_GLASS, materialID);
	frnQIYJjVJ.ice 			= GetMaterialMask(MAT_ID_ICE, materialID);
	frnQIYJjVJ.torch 		= GetMaterialMask(MAT_ID_TORCH, materialID);
	frnQIYJjVJ.lava 		= GetMaterialMask(MAT_ID_LAVA, materialID);
	frnQIYJjVJ.glowstone 	= GetMaterialMask(MAT_ID_GLOWSTONE, materialID);
	frnQIYJjVJ.fire 		= GetMaterialMask(MAT_ID_FIRE, materialID);
	frnQIYJjVJ.litFurnace 	= GetMaterialMask(MAT_ID_LIT_FURNACE, materialID);
	frnQIYJjVJ.beacon 		= GetMaterialMask(MAT_ID_BEACON, materialID);
	frnQIYJjVJ.glowLichen 	= GetMaterialMask(MAT_ID_GLOW_LICHEN, materialID);
	frnQIYJjVJ.glowBerries 	= GetMaterialMask(MAT_ID_GLOW_BERRIES, materialID);

	return frnQIYJjVJ;
}
