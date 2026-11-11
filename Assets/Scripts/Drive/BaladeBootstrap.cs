using CarIdle.Core;
using UnityEngine;

namespace CarIdle.Drive
{
    /// <summary>
    /// Point d'entrée de la scène Balade : construit le monde, la voiture, la caméra drone et
    /// les commandes. La scène elle-même ne contient que cet objet (et une caméra, facultative).
    /// C (ou le bouton VOITURE) passe au modèle suivant du kit, pour comparer les réglages.
    /// </summary>
    public class BaladeBootstrap : MonoBehaviour
    {
        public string StartModel = "suv";

        private DriveInput _input;
        private DroneCamera _camera;
        private CarController _car;
        private int _modelIndex;

        private void Start()
        {
            Application.targetFrameRate = 60;
            // Pas de physique plus fin que le défaut (0,02 s) : les roues sont plus stables.
            Time.fixedDeltaTime = 1f / 60f;

            WorldBuilder.Build();
            _input = gameObject.AddComponent<DriveInput>();

            var cam = Camera.main;
            if (cam == null)
            {
                var go = new GameObject("Camera");
                go.tag = "MainCamera";
                cam = go.AddComponent<Camera>();
                go.AddComponent<AudioListener>();
            }
            cam.fieldOfView = 55f;
            cam.nearClipPlane = 0.3f;
            cam.farClipPlane = 1500f;
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = RenderSettings.fogColor;
            _camera = cam.GetComponent<DroneCamera>();
            if (_camera == null)
                _camera = cam.gameObject.AddComponent<DroneCamera>();

            _modelIndex = Mathf.Max(0, System.Array.IndexOf(VehicleFactory.Models, StartModel));
            float y = WorldLayout.Height(WorldLayout.SpawnX, WorldLayout.SpawnZ) + 1f;
            // Départ sur le sable, tourné vers la ville (vers l'ouest).
            Spawn(new Vector3(WorldLayout.SpawnX, y, WorldLayout.SpawnZ), -90f);

            gameObject.AddComponent<BaladeHud>().Car = () => _car;
        }

        private void Update()
        {
            if (_input.NextCarRequested && _car != null)
            {
                _modelIndex = (_modelIndex + 1) % VehicleFactory.Models.Length;
                var t = _car.transform;
                Vector3 pos = t.position + Vector3.up * 0.5f;
                float yaw = t.eulerAngles.y;
                Destroy(_car.gameObject);
                Spawn(pos, yaw);
            }
        }

        private void Spawn(Vector3 position, float yaw)
        {
            _car = VehicleFactory.Create(VehicleFactory.Models[_modelIndex], position, yaw, _input);
            _camera.Target = _car;
            _camera.Snap();
        }
    }

    /// <summary>Affichage minimal du prototype : vitesse, sol sous les roues, modèle.</summary>
    public class BaladeHud : MonoBehaviour
    {
        public System.Func<CarController> Car;
        private GUIStyle _big, _small;

        private static readonly string[] SurfaceNames = { "Bitume", "Terre", "Sable", "Sable mouillé", "Eau" };

        private void OnGUI()
        {
            var car = Car?.Invoke();
            if (car == null)
                return;
            if (_big == null)
            {
                _big = new GUIStyle(GUI.skin.label) { fontSize = Mathf.Max(22, Screen.height / 14), fontStyle = FontStyle.Bold, alignment = TextAnchor.UpperCenter };
                _big.normal.textColor = new Color(1f, 0.62f, 0.15f);
                _small = new GUIStyle(GUI.skin.label) { fontSize = Mathf.Max(12, Screen.height / 40), alignment = TextAnchor.UpperCenter };
                _small.normal.textColor = Color.white;
            }
            float w = Screen.width;
            GUI.Label(new Rect(0, Screen.height * 0.02f, w, Screen.height * 0.1f), Mathf.RoundToInt(car.SpeedKmh) + " km/h", _big);
            string ground = car.InWater ? "Eau" : SurfaceNames[(int)car.WheelSurface[2]];
            GUI.Label(new Rect(0, Screen.height * 0.11f, w, Screen.height * 0.05f), ground + "  ·  " + car.name, _small);
        }
    }
}
