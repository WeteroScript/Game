using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace ScooterGame
{
    /// <summary>
    /// Runtime PBR material cache. Falls back to the built-in Standard shader when the
    /// URP package is not active, so the game still renders (instead of magenta) if the
    /// render pipeline asset failed to load.
    /// </summary>
    public static class MaterialLibrary
    {
        static readonly Dictionary<string, Material> Cache = new Dictionary<string, Material>();
        static Shader _lit;
        static bool _isUrp;

        public static bool UsingUrp { get { EnsureShader(); return _isUrp; } }

        /// <summary>True when a Universal Render Pipeline asset is the active pipeline.</summary>
        static bool UrpIsActive()
        {
            RenderPipelineAsset pipeline = GraphicsSettings.currentRenderPipeline;
            if (pipeline == null) return false;
            return pipeline.GetType().Name.IndexOf("Universal", System.StringComparison.OrdinalIgnoreCase) >= 0;
        }

        static void EnsureShader()
        {
            if (_lit != null) return;

            // Pick the shader family that matches the ACTIVE pipeline, otherwise the surfaces
            // would render magenta when the URP asset could not be assigned.
            if (UrpIsActive())
            {
                _lit = Shader.Find("Universal Render Pipeline/Lit");
                if (_lit != null)
                {
                    _isUrp = true;
                    return;
                }
            }

            _lit = Shader.Find("Standard");
            if (_lit != null)
            {
                _isUrp = false;
                return;
            }

            _lit = Shader.Find("Universal Render Pipeline/Lit");
            if (_lit != null)
            {
                _isUrp = true;
                return;
            }

            _lit = Shader.Find("Diffuse");
            _isUrp = false;
        }

        public static Material Get(string key, Color color, float metallic, float smoothness)
        {
            Material cached;
            if (Cache.TryGetValue(key, out cached) && cached != null) return cached;

            EnsureShader();
            Material mat = new Material(_lit);
            mat.name = "MAT_" + key;
            mat.hideFlags = HideFlags.DontSave;

            if (mat.HasProperty("_BaseColor")) mat.SetColor("_BaseColor", color);
            if (mat.HasProperty("_Color")) mat.SetColor("_Color", color);
            if (mat.HasProperty("_Metallic")) mat.SetFloat("_Metallic", Mathf.Clamp01(metallic));
            if (mat.HasProperty("_Smoothness")) mat.SetFloat("_Smoothness", Mathf.Clamp01(smoothness));
            if (mat.HasProperty("_Glossiness")) mat.SetFloat("_Glossiness", Mathf.Clamp01(smoothness));

            Cache[key] = mat;
            return mat;
        }

        public static Material Emissive(string key, Color color, float intensity)
        {
            Material cached;
            if (Cache.TryGetValue(key, out cached) && cached != null) return cached;

            EnsureShader();
            Material mat = new Material(_lit);
            mat.name = "MAT_" + key;
            mat.hideFlags = HideFlags.DontSave;

            if (mat.HasProperty("_BaseColor")) mat.SetColor("_BaseColor", color);
            if (mat.HasProperty("_Color")) mat.SetColor("_Color", color);
            if (mat.HasProperty("_EmissionColor")) mat.SetColor("_EmissionColor", color * intensity);
            mat.EnableKeyword("_EMISSION");
            mat.globalIlluminationFlags = MaterialGlobalIlluminationFlags.None;

            Cache[key] = mat;
            return mat;
        }

        /// <summary>Copy of a material with a different UV tiling (large surfaces would stretch otherwise).</summary>
        public static Material Tiled(Material source, string key, float u, float v)
        {
            Material cached;
            if (Cache.TryGetValue(key, out cached) && cached != null) return cached;
            if (source == null) return null;

            Material clone = new Material(source);
            clone.name = "MAT_" + key;
            clone.hideFlags = HideFlags.DontSave;
            clone.mainTextureScale = new Vector2(u, v);
            Cache[key] = clone;
            return clone;
        }

        // ---- vehicles ----------------------------------------------------------

        public static Material Frame(Color color)
        {
            return Get("frame_" + ColorKey(color), color, 0.65f, 0.38f);
        }

        public static Material Deck(Color color)
        {
            return Get("deck_" + ColorKey(color), color, 0.2f, 0.22f);
        }

        public static Material Metal(string key, Color color, float smoothness)
        {
            return Get("metal_" + key, color, 0.9f, smoothness);
        }

        public static Material Tire
        {
            get { return Get("tire", new Color(0.055f, 0.055f, 0.06f), 0f, 0.12f); }
        }

        public static Material Rim
        {
            get { return Get("rim", new Color(0.19f, 0.2f, 0.22f), 0.85f, 0.62f); }
        }

        public static Material MotorHub
        {
            get { return Get("motor", new Color(0.24f, 0.25f, 0.27f), 0.95f, 0.55f); }
        }

        public static Material Chrome
        {
            get { return Get("chrome", new Color(0.78f, 0.79f, 0.82f), 1f, 0.88f); }
        }

        public static Material Glass
        {
            get { return Get("glass", new Color(0.06f, 0.09f, 0.12f), 0.3f, 0.92f); }
        }

        public static Material Screen
        {
            get { return Emissive("screen", new Color(0.35f, 0.95f, 1f), 2.2f); }
        }

        public static Material Headlight
        {
            get { return Emissive("headlight", new Color(1f, 0.97f, 0.86f), 3.4f); }
        }

        public static Material Taillight
        {
            get { return Emissive("taillight", new Color(1f, 0.12f, 0.08f), 2.6f); }
        }

        public static Material TurnSignal
        {
            get { return Emissive("turn", new Color(1f, 0.62f, 0.05f), 2.4f); }
        }

        public static Material BrakeRotor
        {
            get { return Get("rotor", new Color(0.42f, 0.43f, 0.45f), 1f, 0.72f); }
        }

        public static Material Caliper
        {
            get { return Get("caliper", new Color(0.62f, 0.08f, 0.07f), 0.5f, 0.45f); }
        }

        // ---- world -------------------------------------------------------------

        public static Material Asphalt
        {
            get
            {
                Material m = Get("asphalt", new Color(0.16f, 0.165f, 0.175f), 0f, 0.18f);
                AttachNoise(m, "asphalt_tex", new Color(0.09f, 0.09f, 0.1f), new Color(0.2f, 0.2f, 0.21f), 22f, 3f, 1);
                return m;
            }
        }

        public static Material Concrete
        {
            get
            {
                Material m = Get("concrete", new Color(0.52f, 0.52f, 0.5f), 0f, 0.22f);
                AttachNoise(m, "concrete_tex", new Color(0.42f, 0.42f, 0.4f), new Color(0.6f, 0.6f, 0.58f), 30f, 4f, 2);
                return m;
            }
        }

        public static Material Sidewalk
        {
            get
            {
                Material m = Get("sidewalk", new Color(0.6f, 0.6f, 0.58f), 0f, 0.26f);
                AttachNoise(m, "sidewalk_tex", new Color(0.5f, 0.5f, 0.48f), new Color(0.68f, 0.68f, 0.66f), 14f, 2f, 3);
                return m;
            }
        }

        public static Material Dirt
        {
            get
            {
                Material m = Get("dirt", new Color(0.42f, 0.34f, 0.24f), 0f, 0.15f);
                AttachNoise(m, "dirt_tex", new Color(0.34f, 0.27f, 0.19f), new Color(0.52f, 0.43f, 0.31f), 18f, 3f, 4);
                return m;
            }
        }

        public static Material Grass
        {
            get
            {
                Material m = Get("grass", new Color(0.24f, 0.34f, 0.17f), 0f, 0.16f);
                AttachNoise(m, "grass_tex", new Color(0.17f, 0.26f, 0.12f), new Color(0.32f, 0.44f, 0.22f), 26f, 2.5f, 5);
                return m;
            }
        }

        public static Material RoadPaint
        {
            get { return Get("paint", new Color(0.9f, 0.9f, 0.88f), 0f, 0.3f); }
        }

        public static Material Hazard
        {
            get { return Get("hazard", new Color(0.95f, 0.72f, 0.05f), 0.1f, 0.35f); }
        }

        public static Material ConeMaterial
        {
            get { return Get("cone", new Color(0.95f, 0.33f, 0.05f), 0.05f, 0.42f); }
        }

        public static Material Barrier
        {
            get { return Get("barrier", new Color(0.82f, 0.83f, 0.85f), 0.35f, 0.35f); }
        }

        public static Material Guardrail
        {
            get { return Get("guardrail", new Color(0.62f, 0.64f, 0.67f), 0.85f, 0.55f); }
        }

        public static Material Steel
        {
            get { return Get("steel", new Color(0.4f, 0.42f, 0.45f), 0.9f, 0.5f); }
        }

        public static Material Wood
        {
            get { return Get("wood", new Color(0.5f, 0.36f, 0.22f), 0f, 0.2f); }
        }

        public static Material Building(int index)
        {
            Color[] colors =
            {
                new Color(0.66f, 0.63f, 0.58f),
                new Color(0.55f, 0.56f, 0.6f),
                new Color(0.72f, 0.66f, 0.58f),
                new Color(0.48f, 0.5f, 0.53f),
                new Color(0.63f, 0.58f, 0.62f)
            };
            int i = Mathf.Abs(index) % colors.Length;
            return Get("building_" + i, colors[i], 0.05f, 0.2f);
        }

        public static Material Window(int index)
        {
            Color[] colors =
            {
                new Color(0.12f, 0.16f, 0.2f),
                new Color(0.18f, 0.2f, 0.22f),
                new Color(0.1f, 0.13f, 0.16f)
            };
            int i = Mathf.Abs(index) % colors.Length;
            return Get("window_" + i, colors[i], 0.7f, 0.85f);
        }

        public static Material WindowLit
        {
            get { return Emissive("window_lit", new Color(1f, 0.88f, 0.62f), 1.6f); }
        }

        public static Material StreetLampGlow
        {
            get { return Emissive("lamp", new Color(1f, 0.92f, 0.72f), 3f); }
        }

        // ---- helpers -----------------------------------------------------------

        static string ColorKey(Color c)
        {
            return Mathf.RoundToInt(c.r * 255f) + "_" + Mathf.RoundToInt(c.g * 255f) + "_" + Mathf.RoundToInt(c.b * 255f);
        }

        static void AttachNoise(Material mat, string texKey, Color dark, Color light, float scale, float tiling, int seed)
        {
            if (mat == null) return;
            Texture2D tex = NoiseTexture(texKey, dark, light, scale, seed);
            if (tex == null) return;
            mat.mainTexture = tex;
            mat.mainTextureScale = new Vector2(tiling, tiling);
        }

        static readonly Dictionary<string, Texture2D> TextureCache = new Dictionary<string, Texture2D>();

        public static Texture2D NoiseTexture(string key, Color dark, Color light, float scale, int seed)
        {
            Texture2D cached;
            if (TextureCache.TryGetValue(key, out cached) && cached != null) return cached;
            if (_lit == null) EnsureShader();

            const int size = 128;
            Texture2D tex = new Texture2D(size, size, TextureFormat.RGBA32, true);
            tex.name = "TEX_" + key;
            tex.wrapMode = TextureWrapMode.Repeat;
            tex.filterMode = FilterMode.Bilinear;
            tex.hideFlags = HideFlags.DontSave;

            System.Random rng = new System.Random(seed * 7919 + 13);
            float ox = (float)rng.NextDouble() * 100f;
            float oy = (float)rng.NextDouble() * 100f;

            Color[] pixels = new Color[size * size];
            for (int y = 0; y < size; y++)
            {
                for (int x = 0; x < size; x++)
                {
                    float u = (float)x / size * scale + ox;
                    float v = (float)y / size * scale + oy;
                    float n = Mathf.PerlinNoise(u, v);
                    float n2 = Mathf.PerlinNoise(u * 4.3f + 11f, v * 4.3f + 7f) * 0.35f;
                    float t = Mathf.Clamp01(n * 0.75f + n2);
                    // sparse speckles to break up the pattern
                    if (rng.NextDouble() < 0.03) t = Mathf.Clamp01(t + 0.35f);
                    pixels[y * size + x] = Color.Lerp(dark, light, t);
                }
            }
            tex.SetPixels(pixels);
            tex.Apply(true, false);

            TextureCache[key] = tex;
            return tex;
        }
    }
}
