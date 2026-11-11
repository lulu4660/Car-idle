// Particules et traces (URP) : texture × couleur du sommet, transparent, sans écriture
// de profondeur. _Scatter éclaire la poussière à contre-jour, comme un nuage de sable
// traversé par le soleil.
Shader "CarIdle/Particle"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Scatter ("Contre-jour", Float) = 0
    }

    SubShader
    {
        Tags { "RenderType" = "Transparent" "Queue" = "Transparent" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True" }

        Pass
        {
            Name "Particle"
            Tags { "LightMode" = "UniversalForward" }
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float _Scatter;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                half4 color : COLOR;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                half4 color : COLOR;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float fogFactor : TEXCOORD2;
            };

            Varyings vert(Attributes v)
            {
                Varyings o;
                o.positionWS = TransformObjectToWorld(v.positionOS.xyz);
                o.positionCS = TransformWorldToHClip(o.positionWS);
                o.color = v.color;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.fogFactor = ComputeFogFactor(o.positionCS.z);
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                half4 c = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv) * i.color;
                if (_Scatter > 0)
                {
                    Light sun = GetMainLight();
                    float3 v = normalize(GetWorldSpaceViewDir(i.positionWS));
                    float back = pow(saturate(dot(-v, sun.direction)), 4.0);
                    c.rgb *= SampleSH(float3(0, 1, 0)) * 0.9 + sun.color * (0.55 + back * _Scatter);
                }
                c.rgb = MixFog(c.rgb, i.fogFactor);
                return c;
            }
            ENDHLSL
        }
    }
}
