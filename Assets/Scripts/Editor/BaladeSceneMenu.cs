using System.Linq;
using CarIdle.Drive;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace CarIdle.EditorTools
{
    /// <summary>
    /// Crée la scène Assets/Scenes/Balade.unity (une caméra et l'objet qui construit tout le
    /// reste au lancement) et l'ajoute aux scènes du build. Fait une fois tout seul à la
    /// première ouverture du projet ; ensuite par le menu Car Idle.
    /// </summary>
    [InitializeOnLoad]
    public static class BaladeSceneMenu
    {
        public const string ScenePath = "Assets/Scenes/Balade.unity";

        static BaladeSceneMenu()
        {
            if (Application.isBatchMode)
                return;
            EditorApplication.delayCall += () =>
            {
                if (!System.IO.File.Exists(ScenePath) && !EditorApplication.isPlayingOrWillChangePlaymode)
                    CreateScene();
            };
        }

        [MenuItem("Car Idle/Recréer la scène Balade")]
        public static void CreateScene()
        {
            if (!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo())
                return;
            WriteScene();
        }

        /// <summary>Crée la scène sans rien demander (utilisé aussi par la build web).</summary>
        public static void WriteScene()
        {
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            var cam = new GameObject("Camera");
            cam.tag = "MainCamera";
            cam.AddComponent<Camera>();
            cam.AddComponent<AudioListener>();
            cam.AddComponent<DroneCamera>();
            cam.transform.position = new Vector3(250f, 25f, 0f);

            var boot = new GameObject("Balade");
            boot.AddComponent<BaladeBootstrap>();

            System.IO.Directory.CreateDirectory("Assets/Scenes");
            EditorSceneManager.SaveScene(scene, ScenePath);

            var scenes = EditorBuildSettings.scenes.ToList();
            if (!scenes.Any(s => s.path == ScenePath))
            {
                scenes.Insert(0, new EditorBuildSettingsScene(ScenePath, true));
                EditorBuildSettings.scenes = scenes.ToArray();
            }
            Debug.Log("Scène Balade prête : appuie sur Play.");
        }
    }
}
