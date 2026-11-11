using System;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;
using UnityEngine.Rendering;

namespace CarIdle.EditorTools
{
    /// <summary>
    /// Build web (WebGL) lancée par GitHub Actions (.github/workflows/web.yml) pour jouer sur
    /// iPhone dans Safari. Crée la scène Balade si besoin, garde les shaders créés par le code
    /// (Shader.Find ne trouve en build que les shaders inclus), compresse en gzip lisible par
    /// GitHub Pages, puis construit dans le dossier donné par -customBuildPath.
    /// </summary>
    public static class WebBuild
    {
        private static readonly string[] CodeShaders =
        {
            "Standard",
            "Sprites/Default",
            "Nature/Terrain/Standard",
            "Universal Render Pipeline/Lit",
            "Universal Render Pipeline/Terrain/Lit",
        };

        [MenuItem("Car Idle/Build web")]
        public static void Build()
        {
            if (!System.IO.File.Exists(BaladeSceneMenu.ScenePath))
                BaladeSceneMenu.WriteScene();
            IncludeShaders();

            PlayerSettings.productName = "Car Idle";
            PlayerSettings.companyName = "Car Idle";
            PlayerSettings.WebGL.compressionFormat = WebGLCompressionFormat.Gzip;
            // GitHub Pages n'envoie pas l'en-tête gzip : le navigateur décompresse lui-même.
            PlayerSettings.WebGL.decompressionFallback = true;
            PlayerSettings.WebGL.dataCaching = true;
            PlayerSettings.runInBackground = false;

            string path = Argument("-customBuildPath") ?? "build/WebGL/WebGL";
            var options = new BuildPlayerOptions
            {
                scenes = new[] { BaladeSceneMenu.ScenePath },
                locationPathName = path,
                target = BuildTarget.WebGL,
                options = BuildOptions.None,
            };
            BuildReport report = BuildPipeline.BuildPlayer(options);
            Debug.Log("Build web : " + report.summary.result + ", " + report.summary.totalSize / (1024 * 1024) + " Mo, " + path);
            if (Application.isBatchMode)
                EditorApplication.Exit(report.summary.result == BuildResult.Succeeded ? 0 : 1);
        }

        private static void IncludeShaders()
        {
            var settings = AssetDatabase.LoadAssetAtPath<GraphicsSettings>("ProjectSettings/GraphicsSettings.asset");
            var so = new SerializedObject(settings);
            var list = so.FindProperty("m_AlwaysIncludedShaders");
            foreach (var name in CodeShaders)
            {
                var shader = Shader.Find(name);
                if (shader == null)
                    continue;
                bool present = false;
                for (int i = 0; i < list.arraySize; i++)
                    present |= list.GetArrayElementAtIndex(i).objectReferenceValue == shader;
                if (present)
                    continue;
                list.InsertArrayElementAtIndex(list.arraySize);
                list.GetArrayElementAtIndex(list.arraySize - 1).objectReferenceValue = shader;
            }
            so.ApplyModifiedProperties();
            AssetDatabase.SaveAssets();
        }

        private static string Argument(string name)
        {
            var args = Environment.GetCommandLineArgs();
            int i = Array.IndexOf(args, name);
            return i >= 0 && i + 1 < args.Length ? args[i + 1] : null;
        }
    }
}
