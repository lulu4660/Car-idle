using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace CarIdle.Drive
{
    /// <summary>
    /// Post-traitement de la balade (URP) : tonemapping ACES, bloom doux sur le soleil et les
    /// reflets de la mer, étalonnage chaud de fin de journée (ombres légèrement froides,
    /// lumières dorées), vignettage. Rien si le rendu URP n'est pas actif.
    /// </summary>
    public static class PostFx
    {
        public static void Setup(Camera cam)
        {
            if (!Materials.IsUrp || cam == null)
                return;

            var data = cam.GetUniversalAdditionalCameraData();
            data.renderPostProcessing = true;
            data.antialiasing = AntialiasingMode.SubpixelMorphologicalAntiAliasing;
            data.antialiasingQuality = AntialiasingQuality.Medium;

            var profile = ScriptableObject.CreateInstance<VolumeProfile>();

            var tone = profile.Add<Tonemapping>(true);
            tone.mode.Override(TonemappingMode.ACES);

            var bloom = profile.Add<Bloom>(true);
            bloom.threshold.Override(1.05f);
            bloom.intensity.Override(0.45f);
            bloom.scatter.Override(0.72f);
            bloom.tint.Override(new Color(1f, 0.86f, 0.70f));

            var color = profile.Add<ColorAdjustments>(true);
            color.postExposure.Override(0.1f);
            color.contrast.Override(18f);
            color.saturation.Override(4f);

            var white = profile.Add<WhiteBalance>(true);
            white.temperature.Override(6f);
            white.tint.Override(1f);

            var split = profile.Add<SplitToning>(true);
            split.shadows.Override(new Color(0.46f, 0.49f, 0.53f));
            split.highlights.Override(new Color(0.56f, 0.51f, 0.45f));
            split.balance.Override(0f);

            var vignette = profile.Add<Vignette>(true);
            vignette.intensity.Override(0.28f);
            vignette.smoothness.Override(0.45f);

            var go = new GameObject("Post-traitement");
            var volume = go.AddComponent<Volume>();
            volume.isGlobal = true;
            volume.priority = 10f;
            volume.sharedProfile = profile;
        }
    }
}
