using UnityEngine;
using UnityEngine.Rendering;

namespace ScooterGame
{
    /// <summary>
    /// Lighting is created at runtime. The sky is a plain camera color plus matching fog,
    /// which keeps the build free of skybox shader / lighting-data dependencies.
    /// </summary>
    public static class SkyAndLighting
    {
        public static Color SkyColorFor(MapId map)
        {
            return map == MapId.StraightTrack
                ? new Color(0.56f, 0.72f, 0.9f)
                : new Color(0.13f, 0.16f, 0.26f);
        }

        public static Light Apply(MapId map, Transform parent)
        {
            bool day = map == MapId.StraightTrack;

            Color skyColor = SkyColorFor(map);
            RenderSettings.fog = true;
            RenderSettings.fogMode = FogMode.Linear;
            RenderSettings.fogColor = skyColor;
            RenderSettings.fogStartDistance = day ? 110f : 55f;
            RenderSettings.fogEndDistance = day ? 380f : 260f;

            RenderSettings.ambientMode = AmbientMode.Trilight;
            if (day)
            {
                RenderSettings.ambientSkyColor = new Color(0.62f, 0.72f, 0.86f);
                RenderSettings.ambientEquatorColor = new Color(0.52f, 0.56f, 0.6f);
                RenderSettings.ambientGroundColor = new Color(0.3f, 0.29f, 0.26f);
                RenderSettings.ambientIntensity = 1f;
            }
            else
            {
                RenderSettings.ambientSkyColor = new Color(0.26f, 0.3f, 0.42f);
                RenderSettings.ambientEquatorColor = new Color(0.2f, 0.22f, 0.28f);
                RenderSettings.ambientGroundColor = new Color(0.1f, 0.1f, 0.12f);
                RenderSettings.ambientIntensity = 1f;
            }

            RenderSettings.reflectionIntensity = day ? 0.7f : 0.45f;
            RenderSettings.skybox = null;

            GameObject sunObject = new GameObject("Sun");
            if (parent != null) sunObject.transform.SetParent(parent, false);
            sunObject.transform.rotation = day
                ? Quaternion.Euler(48f, -35f, 0f)
                : Quaternion.Euler(22f, 155f, 0f);

            Light sun = sunObject.AddComponent<Light>();
            sun.type = LightType.Directional;
            sun.color = day ? new Color(1f, 0.96f, 0.88f) : new Color(1f, 0.66f, 0.45f);
            sun.intensity = day ? 1.25f : 0.75f;
            sun.shadows = LightShadows.Soft;
            sun.shadowStrength = day ? 0.8f : 0.9f;
            sun.shadowBias = 0.04f;
            sun.shadowNormalBias = 0.35f;

            RenderSettings.sun = sun;
            return sun;
        }
    }
}
