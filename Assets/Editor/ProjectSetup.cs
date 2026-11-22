#if UNITY_EDITOR
using System;
using System.Collections.Generic;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;

namespace ScooterGame.EditorTools
{
    /// <summary>
    /// Configures the project for an Android URP build automatically when the editor opens
    /// (local or in GameCI). Everything is done through the editor API instead of hand-written
    /// YAML, so a missing or outdated project settings file cannot break the build.
    /// </summary>
    [InitializeOnLoad]
    public static class ProjectSetup
    {
        public const string ScenePath = "Assets/Scenes/Boot.unity";
        const string SettingsFolder = "Assets/Settings";
        const string UrpAssetPath = "Assets/Settings/URP-Android.asset";
        const string RendererDataPath = "Assets/Settings/URP-Renderer.asset";

        static bool _running;

        static ProjectSetup()
        {
            EditorApplication.delayCall += RunAuto;
        }

        static void RunAuto()
        {
            try
            {
                Run(false);
            }
            catch (Exception exception)
            {
                Debug.LogError("[ProjectSetup] Automatic setup failed: " + exception);
            }
        }

        [MenuItem("Scooter/Setup Project (Android + URP)")]
        public static void RunFromMenu()
        {
            Run(true);
        }

        public static void Run(bool verbose)
        {
            if (_running) return;
            _running = true;
            try
            {
                ConfigurePlayerSettings(verbose);
                EnsureBuildScenes(verbose);
                EnsureRenderPipeline(verbose);
                EnsureAlwaysIncludedShaders(verbose);

                AssetDatabase.SaveAssets();
                if (verbose) Debug.Log("[ProjectSetup] Done.");
            }
            finally
            {
                _running = false;
            }
        }

        // ------------------------------------------------------------------------
        static void ConfigurePlayerSettings(bool verbose)
        {
            PlayerSettings.companyName = GameConfig.CompanyName;
            PlayerSettings.productName = GameConfig.ProductName;
            PlayerSettings.bundleVersion = GameConfig.Version;
            PlayerSettings.SetApplicationIdentifier(BuildTargetGroup.Android, GameConfig.BundleId);
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.LandscapeLeft;
            PlayerSettings.allowedAutorotateToPortrait = false;
            PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;
            PlayerSettings.allowedAutorotateToLandscapeLeft = true;
            PlayerSettings.allowedAutorotateToLandscapeRight = true;
            PlayerSettings.colorSpace = ColorSpace.Linear;

            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel24;
            PlayerSettings.Android.targetSdkVersion = AndroidSdkVersions.AndroidApiLevelAuto;
            PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;
            PlayerSettings.Android.bundleVersionCode = Mathf.Max(1, PlayerSettings.Android.bundleVersionCode);
            PlayerSettings.Android.forceInternetPermission = false;
            PlayerSettings.Android.forceSDCardPermission = false;
            PlayerSettings.Android.useCustomKeystore = false;

            PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android, ScriptingImplementation.IL2CPP);

            // GLES3 only: the most compatible backend for a wide range of Android devices.
            PlayerSettings.SetUseDefaultGraphicsAPIs(BuildTarget.Android, false);
            PlayerSettings.SetGraphicsAPIs(BuildTarget.Android, new[] { GraphicsDeviceType.OpenGLES3 });

            EditorUserBuildSettings.buildAppBundle = false;

            if (verbose)
            {
                Debug.Log("[ProjectSetup] Player settings configured: " + GameConfig.BundleId + " / Android / IL2CPP / ARM64");
            }
        }

        static void EnsureBuildScenes(bool verbose)
        {
            if (AssetDatabase.LoadAssetAtPath<SceneAsset>(ScenePath) == null)
            {
                Debug.LogWarning("[ProjectSetup] Scene missing, creating a new empty one at " + ScenePath);
                UnityEngine.SceneManagement.Scene scene =
                    EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Additive);
                EditorSceneManager.SaveScene(scene, ScenePath);
                EditorSceneManager.CloseScene(scene, true);
                AssetDatabase.Refresh();
            }

            List<EditorBuildSettingsScene> scenes = new List<EditorBuildSettingsScene>();
            bool found = false;
            EditorBuildSettingsScene[] current = EditorBuildSettings.scenes;
            for (int i = 0; i < current.Length; i++)
            {
                scenes.Add(current[i]);
                if (current[i].path == ScenePath) found = true;
            }

            if (!found)
            {
                scenes.Insert(0, new EditorBuildSettingsScene(ScenePath, true));
                EditorBuildSettings.scenes = scenes.ToArray();
                if (verbose) Debug.Log("[ProjectSetup] Added " + ScenePath + " to the build scene list.");
            }
        }

        /// <summary>
        /// Creates the URP pipeline asset + renderer data through reflection. Using the
        /// ScriptableObject API avoids shipping hand-written pipeline YAML that is tightly
        /// coupled to a specific URP version.
        /// </summary>
        static void EnsureRenderPipeline(bool verbose)
        {
            RenderPipelineAsset pipeline = AssetDatabase.LoadAssetAtPath<RenderPipelineAsset>(UrpAssetPath);
            if (pipeline == null)
            {
                pipeline = CreateUrpAsset(verbose);
            }

            if (pipeline == null)
            {
                Debug.LogWarning("[ProjectSetup] URP asset is unavailable; the project will use the built-in pipeline. " +
                                 "Materials fall back to the Standard shader.");
                return;
            }

            if (GraphicsSettings.defaultRenderPipeline != pipeline)
            {
                GraphicsSettings.defaultRenderPipeline = pipeline;
            }
            if (QualitySettings.renderPipeline != pipeline)
            {
                QualitySettings.renderPipeline = pipeline;
            }

            if (verbose)
            {
                Debug.Log("[ProjectSetup] URP pipeline assigned: " + UrpAssetPath);
            }
        }

        /// <summary>
        /// The game builds every material at runtime, so no material asset references the
        /// URP shaders. Without this the shader stripping step would remove them and
        /// Shader.Find would return null inside the APK (pink/black surfaces).
        /// </summary>
        static void EnsureAlwaysIncludedShaders(bool verbose)
        {
            string[] shaderNames =
            {
                "Universal Render Pipeline/Lit",
                "Universal Render Pipeline/Unlit",
                "Universal Render Pipeline/Particles/Unlit",
                "Standard"
            };

            UnityEngine.Object[] settings = AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/GraphicsSettings.asset");
            if (settings == null || settings.Length == 0 || settings[0] == null)
            {
                Debug.LogWarning("[ProjectSetup] GraphicsSettings.asset not found, shader inclusion skipped.");
                return;
            }

            SerializedObject serializedSettings = new SerializedObject(settings[0]);
            SerializedProperty list = serializedSettings.FindProperty("m_AlwaysIncludedShaders");
            if (list == null) return;

            int added = 0;
            for (int i = 0; i < shaderNames.Length; i++)
            {
                Shader shader = Shader.Find(shaderNames[i]);
                if (shader == null)
                {
                    if (verbose) Debug.LogWarning("[ProjectSetup] Shader not found: " + shaderNames[i]);
                    continue;
                }

                bool present = false;
                for (int j = 0; j < list.arraySize; j++)
                {
                    if (list.GetArrayElementAtIndex(j).objectReferenceValue == shader)
                    {
                        present = true;
                        break;
                    }
                }
                if (present) continue;

                list.InsertArrayElementAtIndex(list.arraySize);
                list.GetArrayElementAtIndex(list.arraySize - 1).objectReferenceValue = shader;
                added++;
            }

            if (added > 0)
            {
                serializedSettings.ApplyModifiedPropertiesWithoutUndo();
                Debug.Log("[ProjectSetup] Added " + added + " shader(s) to Always Included Shaders.");
            }
        }

        static RenderPipelineAsset CreateUrpAsset(bool verbose)
        {
            if (!AssetDatabase.IsValidFolder(SettingsFolder))
            {
                AssetDatabase.CreateFolder("Assets", "Settings");
            }

            Type rendererDataType = FindType("UnityEngine.Rendering.Universal.UniversalRendererData");
            Type pipelineType = FindType("UnityEngine.Rendering.Universal.UniversalRenderPipelineAsset");
            if (rendererDataType == null || pipelineType == null)
            {
                Debug.LogWarning("[ProjectSetup] URP types not found in the project.");
                return null;
            }

            ScriptableObject rendererData = AssetDatabase.LoadAssetAtPath<ScriptableObject>(RendererDataPath);
            if (rendererData == null)
            {
                rendererData = ScriptableObject.CreateInstance(rendererDataType);
                rendererData.name = "URP-Renderer";
                AssetDatabase.CreateAsset(rendererData, RendererDataPath);
            }

            ScriptableObject pipelineObject = ScriptableObject.CreateInstance(pipelineType);
            pipelineObject.name = "URP-Android";
            AssetDatabase.CreateAsset(pipelineObject, UrpAssetPath);

            SerializedObject serializedPipeline = new SerializedObject(pipelineObject);

            SerializedProperty rendererList = serializedPipeline.FindProperty("m_RendererDataList");
            if (rendererList != null)
            {
                rendererList.arraySize = 1;
                rendererList.GetArrayElementAtIndex(0).objectReferenceValue = rendererData;
            }

            SerializedProperty defaultRendererIndex = serializedPipeline.FindProperty("m_DefaultRendererIndex");
            if (defaultRendererIndex != null) defaultRendererIndex.intValue = 0;

            SerializedProperty shadowDistance = serializedPipeline.FindProperty("m_ShadowDistance");
            if (shadowDistance != null) shadowDistance.floatValue = 70f;

            SerializedProperty shadowCascades = serializedPipeline.FindProperty("m_ShadowCascadeCount");
            if (shadowCascades != null) shadowCascades.intValue = 2;

            SerializedProperty msaa = serializedPipeline.FindProperty("m_MSAA");
            if (msaa != null) msaa.intValue = 4;

            serializedPipeline.ApplyModifiedPropertiesWithoutUndo();
            EditorUtility.SetDirty(pipelineObject);
            EditorUtility.SetDirty(rendererData);
            AssetDatabase.SaveAssets();

            if (verbose) Debug.Log("[ProjectSetup] Created URP asset at " + UrpAssetPath);

            return AssetDatabase.LoadAssetAtPath<RenderPipelineAsset>(UrpAssetPath);
        }

        static Type FindType(string fullName)
        {
            Type type = Type.GetType(fullName + ", Unity.RenderPipelines.Universal.Runtime");
            if (type != null) return type;

            System.Reflection.Assembly[] assemblies = AppDomain.CurrentDomain.GetAssemblies();
            for (int i = 0; i < assemblies.Length; i++)
            {
                try
                {
                    type = assemblies[i].GetType(fullName, false);
                    if (type != null) return type;
                }
                catch
                {
                    // ignored: some dynamic assemblies throw on GetType
                }
            }
            return null;
        }
    }

    /// <summary>Command line entry point: Unity -batchmode -executeMethod ScooterGame.EditorTools.BuildScript.BuildAndroid</summary>
    public static class BuildScript
    {
        public static void BuildAndroid()
        {
            ProjectSetup.Run(true);

            string projectRoot = System.IO.Directory.GetCurrentDirectory();
            string outputDirectory = System.IO.Path.Combine(projectRoot, "build", "Android");
            System.IO.Directory.CreateDirectory(outputDirectory);
            string apkPath = System.IO.Path.Combine(outputDirectory, "KugooFreeride.apk");

            BuildPlayerOptions options = new BuildPlayerOptions();
            options.scenes = new[] { ProjectSetup.ScenePath };
            options.locationPathName = apkPath;
            options.target = BuildTarget.Android;
            options.targetGroup = BuildTargetGroup.Android;
            options.options = BuildOptions.None;

            BuildReport report = BuildPipeline.BuildPlayer(options);
            BuildSummary summary = report.summary;

            if (summary.result == BuildResult.Succeeded)
            {
                Debug.Log("[BuildScript] APK created: " + apkPath + " (" + (summary.totalSize / (1024 * 1024)) + " MB)");
                if (Application.isBatchMode) EditorApplication.Exit(0);
            }
            else
            {
                Debug.LogError("[BuildScript] Build failed: " + summary.result + " (" + summary.totalErrors + " errors)");
                if (Application.isBatchMode) EditorApplication.Exit(1);
            }
        }
    }
}
#endif
