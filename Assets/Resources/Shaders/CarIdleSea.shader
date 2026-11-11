// Mer de la balade (URP) : houle douce, reflet du ciel, scintillement du soleil,
// eau claire et turquoise sur le sable près du bord, écume qui vient mourir sur la plage.
// La profondeur vient d'une carte calculée par le jeu (_DepthMap), pas de la caméra :
// moins cher sur iPhone.
Shader "CarIdle/Sea"
{
    Properties
    {
        _DeepColor ("Eau profonde", Color) = (0.03, 0.16, 0.22, 1)
        _ShallowColor ("Eau peu profonde", Color) = (0.16, 0.55, 0.52, 1)
        _FoamColor ("Écume", Color) = (1, 0.97, 0.92, 1)
        _DepthMap ("Profondeur (R = m / 8)", 2D) = "black" {}
        _DepthRect ("Zone de la carte (x0, z0, taille x, taille z)", Vector) = (-512, -512, 1024, 1024)
        _WaveHeight ("Houle (m)", Float) = 0.25
        _SunGlint ("Scintillement", Float) = 6
    }

    SubShader
    {
        Tags { "RenderType" = "Transparent" "Queue" = "Transparent-50" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Name "Sea"
            Tags { "LightMode" = "UniversalForward" }
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_DepthMap);
            SAMPLER(sampler_DepthMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _DeepColor;
                half4 _ShallowColor;
                half4 _FoamColor;
                float4 _DepthMap_ST;
                float4 _DepthRect;
                float _WaveHeight;
                float _SunGlint;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float fogFactor : TEXCOORD1;
            };

            // Houle : quelques vagues qui arrivent du large (de l'est vers la plage).
            float3 Swell(float2 p, float t)
            {
                float3 r = 0; // hauteur, dérivée x, dérivée z
                float2 dirs[4] = { float2(-1, 0.15), float2(-0.8, -0.55), float2(-0.95, 0.35), float2(-0.4, 0.9) };
                float lens[4] = { 38.0, 21.0, 11.0, 6.5 };
                float amps[4] = { 1.0, 0.5, 0.25, 0.12 };
                [unroll]
                for (int i = 0; i < 4; i++)
                {
                    float2 d = normalize(dirs[i]);
                    float k = 6.28318 / lens[i];
                    float c = sqrt(9.8 / k);
                    float ph = k * (dot(d, p) - c * t);
                    float a = amps[i] * _WaveHeight;
                    r.x += a * sin(ph);
                    r.yz += a * k * cos(ph) * d;
                }
                return r;
            }

            float WaterDepth(float2 p)
            {
                float2 uv = (p - _DepthRect.xy) / _DepthRect.zw;
                return SAMPLE_TEXTURE2D_LOD(_DepthMap, sampler_DepthMap, uv, 0).r * 8.0;
            }

            Varyings vert(Attributes v)
            {
                Varyings o;
                float3 ws = TransformObjectToWorld(v.positionOS.xyz);
                float depth = WaterDepth(ws.xz);
                // La houle s'écrase près du bord.
                ws.y += Swell(ws.xz, _Time.y).x * saturate(depth / 2.0);
                o.positionWS = ws;
                o.positionCS = TransformWorldToHClip(ws);
                o.fogFactor = ComputeFogFactor(o.positionCS.z);
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                float t = _Time.y;
                float2 p = i.positionWS.xz;
                float depth = WaterDepth(p);

                // Normale : houle + rides fines qui bougent.
                float3 s = Swell(p, t);
                float2 ripple = float2(sin(p.x * 1.7 + t * 2.1 + sin(p.y * 0.9)), sin(p.y * 1.9 - t * 1.7 + sin(p.x * 1.1))) * 0.06;
                ripple += float2(sin(p.x * 4.3 - t * 3.3 + p.y * 2.0), sin(p.y * 3.7 + t * 2.9 - p.x * 1.6)) * 0.03;
                float3 n = normalize(float3(-(s.y + ripple.x), 1.0, -(s.z + ripple.y)));

                float3 v = normalize(GetWorldSpaceViewDir(i.positionWS));
                float fresnel = pow(1.0 - saturate(dot(n, v)), 5.0) * 0.9 + 0.04;

                // Couleur de l'eau selon la profondeur.
                float shallow = saturate(depth / 6.0);
                half3 water = lerp(_ShallowColor.rgb, _DeepColor.rgb, shallow);

                Light sun = GetMainLight();
                // Lumière qui traverse les vagues, éclairage diffus du soleil.
                half3 lit = water * (sun.color * (0.35 + 0.65 * saturate(dot(n, sun.direction))) + SampleSH(n));

                // Reflet du ciel et scintillement du soleil.
                float3 r = reflect(-v, n);
                half3 sky = GlossyEnvironmentReflection(r, 0.05, 1.0);
                float3 h = normalize(sun.direction + v);
                float spec = pow(saturate(dot(n, h)), 400.0) * _SunGlint + pow(saturate(dot(n, h)), 60.0) * 0.4;
                half3 color = lerp(lit, sky, fresnel) + sun.color * spec;

                // Écume : ligne du bord qui avance et recule, et traînées plus au large.
                float shore = 1.0 - saturate(depth / 0.9);
                float surf = sin(depth * 5.0 - t * 1.6 + sin(p.y * 0.08) * 2.0) * 0.5 + 0.5;
                float foam = saturate(shore * 1.4 * (0.55 + 0.45 * surf));
                foam = max(foam, smoothstep(0.6, 1.0, surf) * saturate(1.0 - depth / 2.5) * 0.5);
                color = lerp(color, _FoamColor.rgb * (sun.color * 0.8 + 0.3), foam);

                // Transparence : on voit le sable sous quelques centimètres d'eau.
                float alpha = saturate(0.35 + depth * 0.6 + foam + fresnel * 0.5);
                color = MixFog(color, i.fogFactor);
                return half4(color, alpha);
            }
            ENDHLSL
        }
    }
}
