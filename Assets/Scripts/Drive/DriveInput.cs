using UnityEngine;
#if ENABLE_INPUT_SYSTEM
using UnityEngine.InputSystem;
#endif

namespace CarIdle.Drive
{
    /// <summary>
    /// Commandes de conduite : clavier (flèches ou ZQSD/WASD, espace = frein à main, R = replacer,
    /// C = voiture suivante, V = plan de caméra suivant)
    /// et boutons tactiles dessinés à l'écran (gauche/droite en bas à gauche, gaz/frein en bas
    /// à droite, dérapage au-dessus). La souris compte comme un doigt, pour tester sur PC.
    /// Marche avec le nouveau système d'entrées comme avec l'ancien.
    /// </summary>
    public class DriveInput : MonoBehaviour
    {
        public float Throttle { get; private set; }
        public float Brake { get; private set; }
        public float Steer { get; private set; }
        public bool Handbrake { get; private set; }
        public bool ResetRequested { get; private set; }
        public bool NextCarRequested { get; private set; }
        public bool CameraRequested { get; private set; }
        public bool ShowTouchButtons = true;

        private float _steerSmooth;
        private readonly Vector2[] _points = new Vector2[10];
        private int _pointCount;

        // Zones des boutons, en fraction de l'écran (x, y depuis le BAS, largeur, hauteur).
        private static readonly Rect LeftZone = new Rect(0.02f, 0.03f, 0.17f, 0.20f);
        private static readonly Rect RightZone = new Rect(0.21f, 0.03f, 0.17f, 0.20f);
        private static readonly Rect GasZone = new Rect(0.80f, 0.03f, 0.18f, 0.26f);
        private static readonly Rect BrakeZone = new Rect(0.61f, 0.03f, 0.17f, 0.18f);
        private static readonly Rect DriftZone = new Rect(0.80f, 0.31f, 0.18f, 0.12f);
        private static readonly Rect ResetZone = new Rect(0.02f, 0.88f, 0.12f, 0.08f);
        private static readonly Rect CarZone = new Rect(0.86f, 0.88f, 0.12f, 0.08f);
        private static readonly Rect CamZone = new Rect(0.72f, 0.88f, 0.12f, 0.08f);

        private bool _left, _right, _gas, _brake, _drift, _resetWasDown, _carWasDown, _camWasDown;

        private void Update()
        {
            ReadPointers();
            _left = AnyIn(LeftZone);
            _right = AnyIn(RightZone);
            _gas = AnyIn(GasZone);
            _brake = AnyIn(BrakeZone);
            _drift = AnyIn(DriftZone);
            bool resetDown = AnyIn(ResetZone);
            bool carDown = AnyIn(CarZone);
            bool camDown = AnyIn(CamZone);

            float kSteer = 0f, kGas = 0f, kBrake = 0f;
            bool kDrift = false, kReset = false, kCar = false, kCam = false;
#if ENABLE_INPUT_SYSTEM
            var k = Keyboard.current;
            if (k != null)
            {
                if (k.leftArrowKey.isPressed || k.aKey.isPressed || k.qKey.isPressed) kSteer -= 1f;
                if (k.rightArrowKey.isPressed || k.dKey.isPressed) kSteer += 1f;
                if (k.upArrowKey.isPressed || k.wKey.isPressed || k.zKey.isPressed) kGas = 1f;
                if (k.downArrowKey.isPressed || k.sKey.isPressed) kBrake = 1f;
                kDrift = k.spaceKey.isPressed;
                kReset = k.rKey.wasPressedThisFrame;
                kCar = k.cKey.wasPressedThisFrame;
                kCam = k.vKey.wasPressedThisFrame;
            }
#elif ENABLE_LEGACY_INPUT_MANAGER
            if (Input.GetKey(KeyCode.LeftArrow) || Input.GetKey(KeyCode.A) || Input.GetKey(KeyCode.Q)) kSteer -= 1f;
            if (Input.GetKey(KeyCode.RightArrow) || Input.GetKey(KeyCode.D)) kSteer += 1f;
            if (Input.GetKey(KeyCode.UpArrow) || Input.GetKey(KeyCode.W) || Input.GetKey(KeyCode.Z)) kGas = 1f;
            if (Input.GetKey(KeyCode.DownArrow) || Input.GetKey(KeyCode.S)) kBrake = 1f;
            kDrift = Input.GetKey(KeyCode.Space);
            kReset = Input.GetKeyDown(KeyCode.R);
            kCar = Input.GetKeyDown(KeyCode.C);
            kCam = Input.GetKeyDown(KeyCode.V);
#endif
            float steerTarget = Mathf.Clamp(kSteer + (_right ? 1f : 0f) - (_left ? 1f : 0f), -1f, 1f);
            // Le volant revient plus vite au centre qu'il ne braque : plus facile au doigt.
            float rate = Mathf.Abs(steerTarget) > Mathf.Abs(_steerSmooth) ? 4f : 7f;
            _steerSmooth = Mathf.MoveTowards(_steerSmooth, steerTarget, rate * Time.deltaTime);
            Steer = _steerSmooth;
            Throttle = Mathf.Max(kGas, _gas ? 1f : 0f);
            Brake = Mathf.Max(kBrake, _brake ? 1f : 0f);
            Handbrake = kDrift || _drift;
            ResetRequested = kReset || (resetDown && !_resetWasDown);
            _resetWasDown = resetDown;
            NextCarRequested = kCar || (carDown && !_carWasDown);
            _carWasDown = carDown;
            CameraRequested = kCam || (camDown && !_camWasDown);
            _camWasDown = camDown;
        }

        private void ReadPointers()
        {
            _pointCount = 0;
#if ENABLE_INPUT_SYSTEM
            var ts = Touchscreen.current;
            if (ts != null)
            {
                foreach (var t in ts.touches)
                {
                    if (t.press.isPressed && _pointCount < _points.Length)
                        _points[_pointCount++] = t.position.ReadValue();
                }
            }
            var mouse = Mouse.current;
            if (mouse != null && mouse.leftButton.isPressed && _pointCount < _points.Length)
                _points[_pointCount++] = mouse.position.ReadValue();
#elif ENABLE_LEGACY_INPUT_MANAGER
            for (int i = 0; i < Input.touchCount && _pointCount < _points.Length; i++)
            {
                var t = Input.GetTouch(i);
                if (t.phase != TouchPhase.Ended && t.phase != TouchPhase.Canceled)
                    _points[_pointCount++] = t.position;
            }
            if (Input.touchCount == 0 && Input.GetMouseButton(0))
                _points[_pointCount++] = Input.mousePosition;
#endif
        }

        private bool AnyIn(Rect zone)
        {
            var r = ToPixels(zone);
            for (int i = 0; i < _pointCount; i++)
            {
                if (r.Contains(_points[i]))
                    return true;
            }
            return false;
        }

        /// <summary>Zone en pixels, y depuis le bas (repère des touches).</summary>
        private static Rect ToPixels(Rect z)
        {
            return new Rect(z.x * Screen.width, z.y * Screen.height, z.width * Screen.width, z.height * Screen.height);
        }

        private GUIStyle _style;

        private void OnGUI()
        {
            if (!ShowTouchButtons)
                return;
            if (_style == null)
            {
                _style = new GUIStyle(GUI.skin.box)
                {
                    alignment = TextAnchor.MiddleCenter,
                    fontSize = Mathf.Max(14, Screen.height / 32),
                    fontStyle = FontStyle.Bold,
                };
                _style.normal.textColor = Color.white;
            }
            DrawButton(LeftZone, "◀", _left);
            DrawButton(RightZone, "▶", _right);
            DrawButton(BrakeZone, "FREIN", _brake);
            DrawButton(GasZone, "GAZ", _gas);
            DrawButton(DriftZone, "DÉRAPAGE", _drift);
            DrawButton(ResetZone, "REPLACER", false);
            DrawButton(CarZone, "VOITURE", false);
            DrawButton(CamZone, "CAMÉRA", false);
        }

        private void DrawButton(Rect zone, string label, bool pressed)
        {
            // OnGUI compte y depuis le HAUT de l'écran.
            var r = new Rect(zone.x * Screen.width, (1f - zone.y - zone.height) * Screen.height, zone.width * Screen.width, zone.height * Screen.height);
            var old = GUI.color;
            GUI.color = pressed ? new Color(1f, 0.55f, 0.15f, 0.85f) : new Color(1f, 1f, 1f, 0.45f);
            GUI.Box(r, label, _style);
            GUI.color = old;
        }
    }
}
