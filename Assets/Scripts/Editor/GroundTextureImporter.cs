using UnityEditor;

namespace CarIdle.EditorTools
{
    /// <summary>
    /// Réglages d'import des textures de Resources/Ground : normales en « Normal map »,
    /// couleurs en sRGB avec la brillance dans l'alpha, ciel HDR panoramique sans mipmaps.
    /// </summary>
    public class GroundTextureImporter : AssetPostprocessor
    {
        private void OnPreprocessTexture()
        {
            if (!assetPath.Replace('\\', '/').Contains("/Resources/Ground/"))
                return;
            var ti = (TextureImporter)assetImporter;
            string name = System.IO.Path.GetFileNameWithoutExtension(assetPath);
            if (name.EndsWith("_normal"))
            {
                ti.textureType = TextureImporterType.NormalMap;
                ti.maxTextureSize = 1024;
            }
            else if (name.StartsWith("sky_"))
            {
                ti.textureType = TextureImporterType.Default;
                ti.textureShape = TextureImporterShape.Texture2D;
                ti.mipmapEnabled = false;
                ti.wrapModeU = UnityEngine.TextureWrapMode.Repeat;
                ti.wrapModeV = UnityEngine.TextureWrapMode.Clamp;
                ti.maxTextureSize = 2048;
            }
            else
            {
                ti.textureType = TextureImporterType.Default;
                ti.sRGBTexture = true;
                ti.alphaSource = TextureImporterAlphaSource.FromInput;
                ti.alphaIsTransparency = false;
                ti.maxTextureSize = 1024;
            }
            ti.anisoLevel = 4;
        }
    }
}
