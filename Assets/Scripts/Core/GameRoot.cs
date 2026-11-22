using UnityEngine;
using UnityEngine.Rendering;

namespace ScooterGame
{
    /// <summary>
    /// Owns the session: menu, world, scooter, camera, HUD, scoring and the run timer.
    /// Created once at startup by <see cref="GameBootstrap"/>.
    /// </summary>
    public class GameRoot : MonoBehaviour
    {
        public static GameRoot Instance { get; private set; }

        Canvas _canvas;
        GameObject _gameLayer;
        MenuScreen _menu;
        Hud _hud;
        TouchControls _touch;
        Camera _camera;
        CameraRig _cameraRig;
        Volume _postFxVolume;

        WorldContext _world;
        ScooterController _scooter;
        TrickSystem _tricks;

        GameMode _mode = GameMode.FreeRide;
        MapId _map = MapId.StraightTrack;
        float _runTimer;
        float _timeLimit;
        bool _running;
        bool _runFinished;
        int _nextCheckpoint;
        int _finalScore;
        float _finalTime;
        float _bestTime = -1f;
        int _bestScore;
        bool _postFxHighQuality;

        public bool IsRunning { get { return _running; } }
        public bool RunFinished { get { return _runFinished; } }
        public ScooterController Scooter { get { return _scooter; } }
        public TrickSystem Tricks { get { return _tricks; } }
        public int Score { get { return _tricks != null ? _tricks.Score : 0; } }
        public int Combo { get { return _tricks != null ? _tricks.Combo : 0; } }
        public float ComboMultiplier { get { return _tricks != null ? _tricks.ComboMultiplier : 1f; } }
        public float RunTimer { get { return _runTimer; } }
        public GameMode Mode { get { return _mode; } }
        public MapId CurrentMap { get { return _map; } }
        public float TimeRemaining { get { return _runFinished ? 0f : Mathf.Max(0f, _timeLimit - _runTimer); } }
        public float BestTime { get { return _bestTime; } }
        public int BestScore { get { return _bestScore; } }

        public string ModeName
        {
            get
            {
                switch (_mode)
                {
                    case GameMode.TimeAttack: return "TIME ATTACK";
                    case GameMode.Freestyle: return "FREESTYLE";
                    default: return "СВОБОДНАЯ ЕЗДА";
                }
            }
        }

        public string MapName
        {
            get { return _map == MapId.StraightTrack ? "ПРЯМАЯ ТРАССА" : "ГОРОД"; }
        }

        // ------------------------------------------------------------------------
        public void Initialize()
        {
            Instance = this;

            Application.targetFrameRate = GameConfig.TargetFrameRate;
            QualitySettings.vSyncCount = 0;
            Screen.sleepTimeout = SleepTimeout.NeverSleep;
            Physics.gravity = new Vector3(0f, GameConfig.Gravity, 0f);

            UiFactory.EnsureEventSystem();

            BuildCamera();
            BuildUi();

            _menu = MenuScreen.Create(_canvas.transform, OnStartRequested);
            _menu.Show();

            _gameLayer.SetActive(false);
        }

        void BuildCamera()
        {
            GameObject cameraObject = new GameObject("MainCamera");
            cameraObject.tag = "MainCamera";
            DontDestroyOnLoad(cameraObject);

            _camera = cameraObject.AddComponent<Camera>();
            _camera.clearFlags = CameraClearFlags.SolidColor;
            _camera.backgroundColor = SkyAndLighting.SkyColorFor(MapId.StraightTrack);
            _camera.nearClipPlane = 0.12f;
            _camera.farClipPlane = 450f;
            _camera.fieldOfView = 60f;
            _camera.allowHDR = true;

            cameraObject.AddComponent<AudioListener>();
            _cameraRig = cameraObject.AddComponent<CameraRig>();

            if (GameConfig.PostProcessingEnabled)
            {
                _postFxHighQuality = SystemInfo.systemMemorySize >= 2600;
                _postFxVolume = PostFx.Apply(_camera, _postFxHighQuality);
            }
        }

        void BuildUi()
        {
            _canvas = UiFactory.CreateCanvas("UICanvas", 0);
            DontDestroyOnLoad(_canvas.gameObject);

            _gameLayer = new GameObject("GameLayer", typeof(RectTransform));
            RectTransform gameRect = _gameLayer.GetComponent<RectTransform>();
            gameRect.SetParent(_canvas.transform, false);
            gameRect.anchorMin = Vector2.zero;
            gameRect.anchorMax = Vector2.one;
            gameRect.offsetMin = Vector2.zero;
            gameRect.offsetMax = Vector2.zero;

            _hud = Hud.Create(_gameLayer.transform);
            _touch = TouchControls.Create(_gameLayer.transform,
                OnDriveTogglePressed, OnSpeedModePressed, OnRespawnPressed, OnMenuPressed);
        }

        // ---- menu callbacks ----------------------------------------------------
        void OnStartRequested(string scooterId, MapId map, GameMode mode)
        {
            StartRun(scooterId, map, mode);
        }

        void OnDriveTogglePressed()
        {
            if (_scooter != null) _scooter.ToggleDrive();
        }

        void OnSpeedModePressed()
        {
            if (_scooter != null) _scooter.CycleSpeedMode();
        }

        void OnRespawnPressed()
        {
            if (_scooter != null) _scooter.Respawn();
        }

        void OnMenuPressed()
        {
            ReturnToMenu();
        }

        // ---- run flow ----------------------------------------------------------
        public void StartRun(string scooterId, MapId map, GameMode mode)
        {
            TeardownWorld();

            PlayerInput.ResetAll();
            TouchState.ClearAll();

            _mode = mode;
            _map = map;
            _runTimer = 0f;
            _runFinished = false;
            _nextCheckpoint = 0;
            _finalScore = 0;
            _finalTime = 0f;
            _timeLimit = mode == GameMode.Freestyle
                ? GameConfig.FreestyleDuration
                : (mode == GameMode.TimeAttack ? GameConfig.TimeAttackLimit : float.MaxValue);

            _world = WorldBuilder.Build(map);

            ScooterSpec spec = ScooterSpec.Get(scooterId);
            _scooter = ScooterFactory.Build(spec, _world.Root, _world.SpawnPosition, _world.SpawnRotation);
            _scooter.SetRespawnPoint(_world.SpawnPosition, _world.SpawnRotation);
            _scooter.OnCrash += HandleCrash;
            _scooter.OnRespawn += HandleRespawn;

            _cameraRig.SetTarget(_scooter);
            _camera.backgroundColor = SkyAndLighting.SkyColorFor(map);

            _tricks = new TrickSystem();
            _tricks.OnTrick += HandleTrick;

            for (int i = 0; i < _world.Checkpoints.Count; i++)
            {
                _world.Checkpoints[i].ResetProgress();
            }

            _menu.Hide();
            _gameLayer.SetActive(true);
            _running = true;

            _hud.ShowBanner(MapName + " · " + ModeName, 2.2f);
        }

        public void RestartRun()
        {
            if (_scooter == null || _scooter.Spec == null) return;
            StartRun(_scooter.Spec.Id, _map, _mode);
        }

        public void ReturnToMenu()
        {
            TeardownWorld();
            _running = false;
            PlayerInput.ResetAll();
            TouchState.ClearAll();
            if (_gameLayer != null) _gameLayer.SetActive(false);
            if (_menu != null) _menu.Show();
        }

        void TeardownWorld()
        {
            if (_scooter != null)
            {
                _scooter.OnCrash -= HandleCrash;
                _scooter.OnRespawn -= HandleRespawn;
            }
            if (_tricks != null)
            {
                _tricks.OnTrick -= HandleTrick;
            }

            if (_world != null)
            {
                _world.Destroy();
                _world = null;
            }
            if (_cameraRig != null) _cameraRig.SetTarget(null);
            _scooter = null;
            _tricks = null;
        }

        // ---- per frame ---------------------------------------------------------
        void Update()
        {
            if (!_running || _scooter == null) return;

            float dt = Time.deltaTime;

            if (PlayerInput.ConsumeMenu())
            {
                ReturnToMenu();
                return;
            }

            if (PlayerInput.ConsumeRespawn()) _scooter.Respawn();
            if (PlayerInput.ConsumeDriveToggle()) _scooter.ToggleDrive();

            int requestedMode = PlayerInput.ConsumeSpeedModeRequest();
            if (requestedMode >= 0) _scooter.SetSpeedMode(requestedMode);

            if (!_runFinished)
            {
                _runTimer += dt;

                if (_mode == GameMode.Freestyle && _runTimer >= GameConfig.FreestyleDuration)
                {
                    FinishRun();
                }
                else if (_mode == GameMode.TimeAttack && _runTimer >= GameConfig.TimeAttackLimit)
                {
                    FinishRun();
                }
            }

            if (_tricks != null) _tricks.Tick(dt, _scooter);

            if (_scooter.transform.position.y < -25f)
            {
                _scooter.Respawn();
            }

            if (_hud != null) _hud.Tick(_scooter, this);
        }

        void FinishRun()
        {
            if (_runFinished) return;
            _runFinished = true;
            _finalScore = Score;
            _finalTime = _runTimer;

            if (_mode == GameMode.TimeAttack)
            {
                if (_bestTime < 0f || _finalTime < _bestTime) _bestTime = _finalTime;
                _hud.ShowBanner("ФИНИШ · " + Hud.FormatTime(_finalTime) + " · ОЧКИ " + _finalScore, 4f);
            }
            else if (_mode == GameMode.Freestyle)
            {
                if (_finalScore > _bestScore) _bestScore = _finalScore;
                _hud.ShowBanner("ВРЕМЯ ВЫШЛО · " + _finalScore + " ОЧКОВ", 4f);
            }
        }

        // ---- events ------------------------------------------------------------
        void HandleCrash(string reason)
        {
            if (_hud != null) _hud.ShowBanner("ПАДЕНИЕ: " + reason, 2.2f);
            if (_tricks != null) _tricks.BreakCombo();
        }

        void HandleRespawn()
        {
            if (_hud != null) _hud.ShowBanner("ПОЕХАЛИ", 1f);
        }

        void HandleTrick(string name, int points)
        {
            if (_hud != null) _hud.ShowTrick(name, points);
        }

        /// <summary>Returns true when the gate counts for the current run.</summary>
        public bool OnCheckpointReached(Checkpoint checkpoint, ScooterController scooter)
        {
            if (checkpoint == null || scooter == null) return false;

            if (_mode == GameMode.TimeAttack && checkpoint.Index != _nextCheckpoint)
            {
                return false;
            }

            scooter.SetRespawnPoint(checkpoint.RespawnPosition, checkpoint.RespawnRotation);

            if (_mode == GameMode.TimeAttack)
            {
                _nextCheckpoint++;

                if (checkpoint.IsFinal)
                {
                    FinishRun();
                }
                else
                {
                    int total = _world != null ? _world.Checkpoints.Count : 0;
                    _hud.ShowBanner("ЧЕКПОИНТ " + _nextCheckpoint + " / " + total, 1.6f);
                }
            }
            else if (checkpoint.IsFinal)
            {
                _hud.ShowBanner("КРУГ ЗАМКНУТ", 1.6f);
            }

            return true;
        }

        void OnDestroy()
        {
            if (Instance == this) Instance = null;
        }
    }

    public static class GameBootstrap
    {
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        static void Boot()
        {
            if (GameRoot.Instance != null) return;

            GameObject root = new GameObject("GameRoot");
            Object.DontDestroyOnLoad(root);

            GameRoot gameRoot = root.AddComponent<GameRoot>();
            gameRoot.Initialize();
        }
    }
}
