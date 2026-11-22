using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace ScooterGame
{
    /// <summary>
    /// URP post processing (bloom + motion blur + DOF). Wrapped in try/catch so a missing
    /// or misconfigured render pipeline never breaks gameplay.
    /// </summary>
    public static class PostFx
    {
        public static Volume Apply(Camera camera, bool highQuality)
        {
            if (camera == null) return null;

            try
            {
                UniversalAdditionalCameraData data = camera.GetComponent<UniversalAdditionalCameraData>();
                if (data == null) data = camera.gameObject.AddComponent<UniversalAdditionalCameraData>();
                data.renderPostProcessing = true;
                data.antialiasing = AntialiasingMode.FastApproximateAntialiasing;
                data.antialiasingQuality = AntialiasingQuality.Medium;

                GameObject volumeObject = new GameObject("PostFxVolume");
                Volume volume = volumeObject.AddComponent<Volume>();
                volume.isGlobal = true;
                volume.priority = 1f;

                VolumeProfile profile = ScriptableObject.CreateInstance<VolumeProfile>();
                profile.name = "RuntimePostFx";
                profile.hideFlags = HideFlags.DontSave;
                volume.profile = profile;

                Bloom bloom = profile.Add<Bloom>(true);
                if (bloom != null)
                {
                    bloom.intensity.value = 0.55f;
                    bloom.threshold.value = 1.05f;
                    bloom.scatter.value = 0.62f;
                }

                if (highQuality)
                {
                    MotionBlur motionBlur = profile.Add<MotionBlur>(true);
                    if (motionBlur != null)
                    {
                        motionBlur.mode.value = MotionBlurMode.CameraOnly;
                        motionBlur.quality.value = MotionBlurQuality.Low;
                        motionBlur.intensity.value = 0.35f;
                    }

                    DepthOfField dof = profile.Add<DepthOfField>(true);
                    if (dof != null)
                    {
                        dof.mode.value = DepthOfFieldMode.Gaussian;
                        dof.gaussianStart.value = 18f;
                        dof.gaussianEnd.value = 90f;
                        dof.gaussianMaxRadius.value = 0.7f;
                    }
                }

                return volume;
            }
            catch (Exception exception)
            {
                Debug.LogWarning("[PostFx] Post processing unavailable: " + exception.Message);
                return null;
            }
        }
    }
}
