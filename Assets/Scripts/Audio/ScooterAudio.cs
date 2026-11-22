using UnityEngine;

namespace ScooterGame
{
    /// <summary>
    /// Procedural motor whine + wind noise, generated at runtime (no audio assets in the repo).
    /// Pitch and volume follow speed and throttle.
    /// </summary>
    public class ScooterAudio : MonoBehaviour
    {
        ScooterController _scooter;
        AudioSource _engine;
        AudioSource _wind;

        void Start()
        {
            _scooter = GetComponent<ScooterController>();

            try
            {
                _engine = gameObject.AddComponent<AudioSource>();
                _engine.clip = CreateMotorLoop();
                _engine.loop = true;
                _engine.playOnAwake = false;
                _engine.spatialBlend = 0.15f;
                _engine.volume = 0.12f;
                _engine.pitch = 1f;
                _engine.Play();

                _wind = gameObject.AddComponent<AudioSource>();
                _wind.clip = CreateWindLoop();
                _wind.loop = true;
                _wind.playOnAwake = false;
                _wind.spatialBlend = 0.1f;
                _wind.volume = 0f;
                _wind.Play();
            }
            catch (System.Exception exception)
            {
                Debug.LogWarning("[Audio] Disabled: " + exception.Message);
                enabled = false;
            }
        }

        void Update()
        {
            if (_scooter == null || _engine == null) return;

            float maxSpeed = Mathf.Max(1f, _scooter.MaxSpeedKmh);
            float ratio = Mathf.Clamp01(_scooter.SpeedKmh / maxSpeed);

            _engine.pitch = 0.72f + ratio * 1.35f + _scooter.Throttle * 0.22f;
            _engine.volume = Mathf.Lerp(0.05f, 0.22f, _scooter.Throttle) * (1f - ratio * 0.15f);

            if (_wind != null)
            {
                _wind.volume = ratio * ratio * 0.22f;
                _wind.pitch = 0.85f + ratio * 0.55f;
            }
        }

        static AudioClip CreateMotorLoop()
        {
            const int sampleRate = 22050;
            const int length = sampleRate; // exactly one second -> seamless loop
            float[] data = new float[length];

            for (int i = 0; i < length; i++)
            {
                float t = (float)i / sampleRate;
                float value = Mathf.Sin(2f * Mathf.PI * 110f * t) * 0.45f
                              + Mathf.Sin(2f * Mathf.PI * 220f * t) * 0.22f
                              + Mathf.Sin(2f * Mathf.PI * 330f * t) * 0.1f
                              + (Mathf.PerlinNoise(t * 420f, 0.37f) - 0.5f) * 0.18f;
                data[i] = Mathf.Clamp(value * 0.55f, -1f, 1f);
            }

            AudioClip clip = AudioClip.Create("MotorLoop", length, 1, sampleRate, false);
            clip.SetData(data, 0);
            return clip;
        }

        static AudioClip CreateWindLoop()
        {
            const int sampleRate = 22050;
            const int length = sampleRate;
            float[] data = new float[length];

            for (int i = 0; i < length; i++)
            {
                float t = (float)i / sampleRate;
                float n1 = Mathf.PerlinNoise(t * 180f, 1.7f) - 0.5f;
                float n2 = Mathf.PerlinNoise(t * 90f + 13f, 5.3f) - 0.5f;
                data[i] = Mathf.Clamp((n1 * 0.6f + n2 * 0.4f) * 0.9f, -1f, 1f);
            }

            AudioClip clip = AudioClip.Create("WindLoop", length, 1, sampleRate, false);
            clip.SetData(data, 0);
            return clip;
        }
    }
}
