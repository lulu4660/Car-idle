using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace CarIdle.EditorTools
{
    /// <summary>
    /// Active le rendu URP du jeu : crée Assets/Settings/CarIdle-URP.asset (et son renderer),
    /// réglé pour un beau rendu sur iPhone (HDR, ombres douces sur 220 m, MSAA ×4), et le met
    /// dans Graphics et dans tous les niveaux de qualité. Fait tout seul à l'ouverture du
    /// projet si aucun pipeline n'est réglé ; sinon par le menu Car Idle.
    /// </summary>
    [InitializeOnLoad]
    public static class RenderSetup
    {
        public const string AssetPath = "Assets/Settings/CarIdle-URP.asset";
        private const string RendererPath = "Assets/Settings/CarIdle-URP_Renderer.asset";
        private const string PostProcessDataPath = "Packages/com.unity.render-pipelines.universal/Runtime/Data/PostProcessData.asset";

        static RenderSetup()
        {
            EditorApplication.delayCall += () =>
            {
                if (GraphicsSettings.defaultRenderPipeline == null && !EditorApplication.isPlayingOrWillChangePlaymode)
                    Ensure();
            };
        }

        [MenuItem("Car Idle/Régler le rendu URP")]
        public static void Ensure()
        {
            var asset = AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>(AssetPath);
            if (asset == null)
            {
                System.IO.Directory.CreateDirectory("Assets/Settings");
                var renderer = ScriptableObject.CreateInstance<UniversalRendererData>();
                renderer.postProcessData = AssetDatabase.LoadAssetAtPath<PostProcessData>(PostProcessDataPath);
                AssetDatabase.CreateAsset(renderer, RendererPath);
                asset = UniversalRenderPipelineAsset.Create(renderer);
                AssetDatabase.CreateAsset(asset, AssetPath);
            }

            asset.supportsHDR = true;
            asset.msaaSampleCount = 4;
            asset.renderScale = 1f;
            asset.shadowDistance = 220f;
            asset.shadowCascadeCount = 2;
            asset.mainLightShadowmapResolution = 2048;
            asset.supportsCameraDepthTexture = false;
            asset.supportsCameraOpaqueTexture = false;
            // Ombres douces : réglage non public, on passe par le fichier de l'asset.
            var so = new SerializedObject(asset);
            var soft = so.FindProperty("m_SoftShadowsSupported");
            if (soft != null)
                soft.boolValue = true;
            so.ApplyModifiedPropertiesWithoutUndo();
            EditorUtility.SetDirty(asset);

            GraphicsSettings.defaultRenderPipeline = asset;
            // Chaque niveau de qualité utilise le même pipeline.
            var quality = AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/QualitySettings.asset");
            if (quality.Length > 0)
            {
                var qso = new SerializedObject(quality[0]);
                var levels = qso.FindProperty("m_QualitySettings");
                for (int i = 0; levels != null && i < levels.arraySize; i++)
                {
                    var rp = levels.GetArrayElementAtIndex(i).FindPropertyRelative("customRenderPipeline");
                    if (rp != null)
                        rp.objectReferenceValue = asset;
                }
                qso.ApplyModifiedPropertiesWithoutUndo();
            }
            AssetDatabase.SaveAssets();
            Debug.Log("Rendu URP réglé : " + AssetPath);
        }
    }
}
