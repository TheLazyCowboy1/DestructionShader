//Makes rooms look more destroyed

Shader "TheLazyCowboy1/DestructionShader" //Unlit Transparent Vertex Colored Additive 
{
	Properties 
	{
		_MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
	}
	
	Category 
	{
		Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
		ZWrite Off
		//Alphatest Greater 0
		//Blend SrcAlpha OneMinusSrcAlpha 
		Blend Off
		Fog { Color(0,0,0,0) }
		Lighting Off
		Cull Off //we can turn backface culling off because we know nothing will be facing backwards

		BindChannels 
		{
			Bind "Vertex", vertex
			Bind "texcoord", texcoord 
			Bind "Color", color 
		}

		SubShader   
		{	
		
			Pass 
			{
				
				
CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
//#pragma debug

#define testNum 8
//#define testNump1 23
#define dirCount 8
#define maxPileHeight 20
#define rubbleStartDepth 2

// #pragma enable_d3d11_debug_symbols
#include "UnityCG.cginc"
//#include "_Functions.cginc"
//#pragma profileoption NumTemps=64
//#pragma profileoption NumInstructionSlots=2048

sampler2D _MainTex;
uniform float2 _MainTex_TexelSize;
//sampler2D _LevelTex;
//uniform float2 _LevelTex_TexelSize;

uniform float TheLazyCowboy1_DestructionStrength;

sampler2D TheLazyCowboy1_PoleMap;
uniform float4 TheLazyCowboy1_PoleMapPos;

//sampler2D _NoiseTex;
//sampler2D _NoiseTex2;
sampler2D TheLazyCowboy1_ColoredNoiseTex;
uniform float2 TheLazyCowboy1_ColoredNoiseTex_TexelSize;

struct v2f {
    float4  pos : SV_POSITION;
    float2  uv : TEXCOORD0;
    float4 clr : COLOR;
};

float4 _MainTex_ST;

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
    o.clr = v.color;
    return o;
}

inline int depthOfPixel(float4 col) {
	//if (col.r < 0.997f) { // if red <= 254/255
	//	return (uint)(round(col.r * 255) - 1) % 30;
	//}
	//return 30; //sky
	return (col.r < 0.997f) ? ((uint)(round(col.r * 255) - 1) % 30) : 40; //treat the sky as extra deep
}

float4 highFreqNoise(float2 uv, float2 scale) {
	float2 rawLerpFac = 2 * (((uv * scale) % 1) - float2(0.5f, 0.5f));
	rawLerpFac = rawLerpFac * rawLerpFac; //^2 + abs
	float lerpFac = max(rawLerpFac.x, rawLerpFac.y);
	lerpFac = lerpFac * lerpFac; //^4
	lerpFac = lerpFac * lerpFac; //^6
	lerpFac = lerpFac * lerpFac; //^8
	lerpFac = lerpFac * lerpFac; //^10
	float4 n1 = tex2D(TheLazyCowboy1_ColoredNoiseTex, (uv * scale));
	float4 n2 = tex2D(TheLazyCowboy1_ColoredNoiseTex, (uv * scale) + TheLazyCowboy1_ColoredNoiseTex_TexelSize * 10); //10 pixel buffer
	return lerp(n1, n2, lerpFac * 0.5f);
}

half4 addDebris(v2f i, float4 origCol, int origDep) {
	return origCol; //as cool as this function is... it needs WAY more work to be sufficient
	/*
	if (origDep < 2) { //probably can't have rubble piled on it
		//discard;
		return origCol;
	}

	//find ground beneath
	int groundDist = 0;
	int groundDep = 0;
	int groundLayer = 0;
	float4 groundCol = float4(0, 0, 0, 0);
	uint notDone = 1;
	[unroll(maxPileHeight)]
	for (int j = 1; j <= maxPileHeight; j++) {
		if (notDone) {
			float4 col = tex2D(_MainTex, i.uv - float2(0, _MainTex_TexelSize.y * j)); //j pixels down
			int dep = depthOfPixel(col);
			int layer = (uint)dep / 10;
			if (dep < origDep && (dep - layer*10) <= rubbleStartDepth) { // && col.a < 0.15f) { //don't pile on top of destroyed terrain
				groundDist = j;
				groundDep = dep;
				groundLayer = layer;
				groundCol = col;
				notDone = 0; //stop searching
			}
		}
	}

	if (groundDist < 1) { //there is no ground beneath to pile rubble on
		return origCol;
	}

	//check that the ground is actually at least a few pixels thick
	[unroll(3)]
	for (int k = 1; k <= 3; k++) {
		float4 tempGroundCol = tex2D(_MainTex, i.uv - float2(0, _MainTex_TexelSize.y * (groundDist + 2*k))); //up to 6 pixels down from ground
		int tempGroundDep = depthOfPixel(tempGroundCol);
		if (tempGroundDep > groundDep + k) {
			return origCol; //not thick enough ground
		}
	}

	float n = tex2D(TheLazyCowboy1_ColoredNoiseTex, float2(i.uv.x, 0.4f)).g; //1D noise
	n = n - 0.5f; //generally don't apply sky rubble

	float debrisFac = n * TheLazyCowboy1_DestructionStrength * (1.25f - 0.5f*i.uv.y); //more debris on lower screen
	if (groundDist < debrisFac) { //potential for extra rubble from the sky, I guess
		//change depth
		float4 n2 = highFreqNoise(i.uv, float2(15, 15));
		int newDep = rubbleStartDepth + groundLayer * 10
			- (int)round(
				groundDist * saturate(0.7f - 0.02f * debrisFac) //subtract roughly 0.5 * groundDist
				+ 3 * (n2.b - 0.5f)); //noise range -1.5 to 1.5
		if (newDep >= origDep) {
			return origCol; //don't pile rubble behind me!
		}
		if (newDep > 29) {
			return half4(1, 1, 1, 1); //sky
		}
		groundCol.r = groundCol.r + (newDep - groundDep) / 255.0f; //set depth to newDep
		
		//change facing direction
		int red = round(groundCol.r*255);
		int facing = ((uint)(red-1) / 30) % 3;
		int targetFacing = round(saturate((n2.r - 0.5f) * 3 + 0.5f) * 2.3f - 0.4f); //range -0.4 to 1.9. -0.4 to 0.5 = 0 (up), 0.5 to 1.5 = 1 (forward), 1.5 to 1.9 = 2 (down)
		groundCol.r = groundCol.r + ((targetFacing - facing) * 30 / 255.0f); //make facing = targetFacing
		return groundCol;
	}

	return origCol;
	*/
}

half4 frag (v2f i) : SV_Target
{

	float4 origCol = tex2D(_MainTex, i.uv);
	int origDep = depthOfPixel(origCol);

	if (origDep >= 30) {
		//discard;
		return float4(1, 1, 1, 1); //sky has 0 weakness - but we're no longer encoding weakness
		//return addDebris(i, origCol, origDep);
	}

	//const uint dirCount = 4;
	float2 dir[dirCount];
	dir[0] = float2(_MainTex_TexelSize.x, 0); //1,0
	dir[1] = float2(0, _MainTex_TexelSize.y); //0,1
//#if dirCount > 2
	dir[2] = _MainTex_TexelSize; //1,1
	dir[3] = float2(_MainTex_TexelSize.x, -_MainTex_TexelSize.y); //1,-1 (equivalent to -1,1)
//#endif
//#if !THELAZYCOWBOY1_SIMPLERLAYERS //dirCount > 4
	dir[4] = float2(_MainTex_TexelSize.x, 0.5f * _MainTex_TexelSize.y); //1, 0.5
	dir[5] = float2(0.5f * _MainTex_TexelSize.x, _MainTex_TexelSize.y); //0.5, 1
	dir[6] = float2(-0.5f * _MainTex_TexelSize.x, _MainTex_TexelSize.y); //-0.5, 1
	dir[7] = float2(_MainTex_TexelSize.x, -0.5f * _MainTex_TexelSize.y); //1, -0.5
//#endif

	//PROJECT RAYS

	float totalWeakness = 0;
	float directionalWeakness = 0;
	float surroundingDep = 0;
	int doubleOrigDep = origDep+origDep;

	[unroll(dirCount)]
	for (uint d = 0; d < dirCount; d++) {
		[unroll(2)]
		for (int s = -1; s < 2; s = s + 2) {
			uint notDone = 1;

			float pixelOffset = 1;
			float strengthFac = 1;
			float directionWeakness = 0;
			int rayDep = origDep;
			
			[unroll(testNum)]
			for (int k = 1; k <= testNum; k++) {
				if (notDone) {
					float4 col = tex2D(_MainTex, i.uv + s * pixelOffset * dir[d]);
					int dep = depthOfPixel(col);

					if (dep - origDep > 2+k) { //more than 3-pixel difference = structural weakness, apparently
						directionWeakness = strengthFac;
						rayDep = 2*dep + (testNum - k); //add a little extra if the search was short
						notDone = 0; //done searching this direction
					}

					pixelOffset = pixelOffset * 1.8f;
					//strengthFac = strengthFac * 0.8f;
					strengthFac = strengthFac - (1.0f / testNum); //linearly decrease strength
				}
			}

			totalWeakness = totalWeakness + directionWeakness * (1 - 0.7f * s * dir[d].y / _MainTex_TexelSize.y); //erosion is stronger downwards than upwards
			directionalWeakness = directionalWeakness + directionWeakness * s * dir[d].y;
			surroundingDep = surroundingDep + origDep + (rayDep - doubleOrigDep) * 0.5f * directionWeakness; //*0.5f because we multiplied it by 2 earlier
		}
	}

	float4 noiseVal = tex2D(TheLazyCowboy1_ColoredNoiseTex, i.uv);
	totalWeakness = saturate(totalWeakness / (dirCount*2.0f) * (noiseVal.b + 0.5f) - noiseVal.g + 0.3f); //randomly shift it with noise
	//totalWeakness = totalWeakness / (dirCount*2.0f);
	//totalWeakness = saturate(totalWeakness / (dirCount*2.0f) * (noiseVal.b - 0.3f) / (1 - 0.3f)); //map noise range 0.3-1 to 0-1

	/*origCol.r = 0;
	origCol.g = 0;
	origCol.b = totalWeakness;
	return origCol;*/

	//origCol.a = totalWeakness; //encode "weakness" in the alpha channel, since it's free
	//return origCol;

	//remove matter from "weak" areas
	if (totalWeakness > 0) { //don't add negative depth

		//check poleMap
		totalWeakness = totalWeakness * (1 - 0.95f * tex2D(TheLazyCowboy1_PoleMap, i.uv * TheLazyCowboy1_PoleMapPos.zw + TheLazyCowboy1_PoleMapPos.xy).r);

		int depLoss = round(TheLazyCowboy1_DestructionStrength * totalWeakness);
		int newDep = origDep + depLoss;
		surroundingDep = (surroundingDep / 16) + ((totalWeakness+1) * 0.03f * TheLazyCowboy1_DestructionStrength); //allow it to go slightly past surroundingDep
		if (newDep > surroundingDep) { //don't allow more depLoss than surroundingDep
			newDep = surroundingDep;
			depLoss = newDep - origDep;
		}
		//if (depLoss > 10 || newDep > 29) { //the idea was that if something is truly so destroyed, just make it sky. But I think it looks better without that
		//if (newDep > 29) {
		if (newDep > 29 || (surroundingDep >= 30 && depLoss > 6)) { //if we're allowed to be sky and there's a lot of depLoss, make it sky
			return float4(1, 1, 1, 1); //DON'T add debris, because it's so destroyed that there can't be debris...?
			//return addDebris(i, float4(1, 1, 1, 1), newDep);
		}
		origCol.r = origCol.r + (depLoss / 255.0f);

		//change facing angle
		if (depLoss > 0) {
			int red = round(origCol.r*255);
			int facing = ((uint)(red-1) / 30) % 3;
			int targetFacing = round(saturate(
					(facing * 0.25f) + 0.25f //factor 1 = current facing angle
					+ (directionalWeakness / _MainTex_TexelSize.y * (depLoss + 5) * 0.1f) //direction of weakness
					+ (highFreqNoise(i.uv, float2(5, 5)).r - 0.5f) * (depLoss + 3) * 0.3f //factor 3 = noise (stronger as depLoss increases)
				) * 2); //0 (down), 1 (forward), or 2 (up)
			origCol.r = origCol.r + ((targetFacing - facing) * 30 / 255.0f); //make facing = targetFacing
		}

		//return addDebris(i, origCol, newDep);
	}

	return origCol;
	//return addDebris(i, origCol, origDep);

}
ENDCG
				
			}
		} 
	}
}