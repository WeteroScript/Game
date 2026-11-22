using UnityEngine;
using UnityEngine.UI;

namespace ScooterGame
{
    /// <summary>Speedometer and run statistics, laid out for a 1920x1080 landscape screen.</summary>
    public class Hud : MonoBehaviour
    {
        Text _speedText;
        Text _unitText;
        Text _batteryText;
        Text _modeText;
        Text _driveText;
        Text _distanceText;
        Text _timeText;
        Text _scoreText;
        Text _comboText;
        Text _bannerText;
        Text _wheelieText;
        Text _pitchText;
        Text _trickPopup;

        Image _batteryFillImage;
        RectTransform _batteryFill;
        RectTransform _wheelieFill;

        float _bannerTimer;
        float _bannerDuration;
        float _trickTimer;

        public static Hud Create(Transform canvas)
        {
            GameObject go = new GameObject("Hud", typeof(RectTransform));
            RectTransform root = go.GetComponent<RectTransform>();
            root.SetParent(canvas, false);
            root.anchorMin = Vector2.zero;
            root.anchorMax = Vector2.one;
            root.offsetMin = Vector2.zero;
            root.offsetMax = Vector2.zero;

            Hud hud = go.AddComponent<Hud>();
            hud.Build(root);
            return hud;
        }

        void Build(RectTransform root)
        {
            Color white = new Color(0.96f, 0.97f, 0.99f);
            Color dim = new Color(0.75f, 0.78f, 0.83f);
            Color accent = UiFactory.Hex("#FF7318");

            // ---- speed ----
            _speedText = UiFactory.Label(root, "Speed", "0", 132, TextAnchor.UpperLeft, white,
                new Vector2(0f, 1f), new Vector2(0f, 1f), new Vector2(40f, -190f), new Vector2(460f, -40f));
            _unitText = UiFactory.Label(root, "Unit", "КМ/Ч", 34, TextAnchor.UpperLeft, accent,
                new Vector2(0f, 1f), new Vector2(0f, 1f), new Vector2(44f, -232f), new Vector2(260f, -192f));

            // ---- battery ----
            UiFactory.Label(root, "BatteryCaption", "БАТАРЕЯ", 22, TextAnchor.UpperLeft, dim,
                new Vector2(0f, 1f), new Vector2(0f, 1f), new Vector2(40f, -268f), new Vector2(240f, -240f));

            UiFactory.Panel(root, "BatteryFrame", new Color(0.06f, 0.07f, 0.09f, 0.75f),
                new Vector2(0f, 1f), new Vector2(0f, 1f), new Vector2(40f, -300f), new Vector2(400f, -272f));

            _batteryFill = UiFactory.Bar(root, "BatteryBar", new Color(0.06f, 0.07f, 0.09f, 0.75f),
                UiFactory.Hex("#38D66B"),
                new Vector2(0f, 1f), new Vector2(0f, 1f), new Vector2(42f, -298f), new Vector2(398f, -274f),
                out _batteryFillImage);

            _batteryText = UiFactory.Label(root, "BatteryText", "100%", 24, TextAnchor.MiddleLeft, white,
                new Vector2(0f, 1f), new Vector2(0f, 1f), new Vector2(410f, -302f), new Vector2(560f, -270f));

            // ---- gear + drive ----
            _modeText = UiFactory.Label(root, "ModeText", "РЕЖИМ 2", 26, TextAnchor.UpperLeft, white,
                new Vector2(0f, 1f), new Vector2(0f, 1f), new Vector2(40f, -340f), new Vector2(360f, -306f));

            _driveText = UiFactory.Label(root, "DriveText", "RWD", 24, TextAnchor.UpperLeft, accent,
                new Vector2(0f, 1f), new Vector2(0f, 1f), new Vector2(372f, -340f), new Vector2(560f, -306f));

            // ---- distance / time (top right) ----
            _distanceText = UiFactory.Label(root, "DistanceText", "0.00 КМ", 30, TextAnchor.UpperRight, white,
                new Vector2(1f, 1f), new Vector2(1f, 1f), new Vector2(-430f, -190f), new Vector2(-30f, -152f));

            _timeText = UiFactory.Label(root, "TimeText", "00:00", 30, TextAnchor.UpperRight, dim,
                new Vector2(1f, 1f), new Vector2(1f, 1f), new Vector2(-430f, -232f), new Vector2(-30f, -194f));

            // ---- score ----
            UiFactory.Label(root, "ScoreCaption", "ОЧКИ", 22, TextAnchor.UpperRight, dim,
                new Vector2(1f, 1f), new Vector2(1f, 1f), new Vector2(-430f, -266f), new Vector2(-30f, -238f));

            _scoreText = UiFactory.Label(root, "ScoreText", "0", 52, TextAnchor.UpperRight, white,
                new Vector2(1f, 1f), new Vector2(1f, 1f), new Vector2(-430f, -330f), new Vector2(-30f, -262f));

            _comboText = UiFactory.Label(root, "ComboText", "", 26, TextAnchor.UpperRight, accent,
                new Vector2(1f, 1f), new Vector2(1f, 1f), new Vector2(-430f, -368f), new Vector2(-30f, -334f));

            // ---- banner ----
            _bannerText = UiFactory.Label(root, "Banner", "", 40, TextAnchor.MiddleCenter, white,
                new Vector2(0.5f, 1f), new Vector2(0.5f, 1f), new Vector2(-520f, -180f), new Vector2(520f, -110f));

            // ---- wheelie gauge (bottom center) ----
            UiFactory.Label(root, "WheelieCaption", "WHEELIE", 22, TextAnchor.MiddleLeft, dim,
                new Vector2(0.5f, 0f), new Vector2(0.5f, 0f), new Vector2(-230f, 350f), new Vector2(-120f, 380f));

            UiFactory.Panel(root, "WheelieFrame", new Color(0.06f, 0.07f, 0.09f, 0.75f),
                new Vector2(0.5f, 0f), new Vector2(0.5f, 0f), new Vector2(-110f, 350f), new Vector2(230f, 380f));

            // balance zone highlight: 25..55 deg out of 80
            UiFactory.Panel(root, "WheelieZone", new Color(0.22f, 0.85f, 0.45f, 0.35f),
                new Vector2(0.5f, 0f), new Vector2(0.5f, 0f),
                new Vector2(-110f + 340f * (25f / 80f), 350f), new Vector2(-110f + 340f * (55f / 80f), 380f));

            _wheelieFill = UiFactory.Bar(root, "WheelieBar", new Color(0f, 0f, 0f, 0f), UiFactory.Hex("#FF7318"),
                new Vector2(0.5f, 0f), new Vector2(0.5f, 0f), new Vector2(-110f, 352f), new Vector2(230f, 378f),
                out Image wheelieImage);
            wheelieImage.color = new Color(1f, 0.45f, 0.1f, 0.85f);

            _pitchText = UiFactory.Label(root, "PitchText", "0°", 24, TextAnchor.MiddleLeft, white,
                new Vector2(0.5f, 0f), new Vector2(0.5f, 0f), new Vector2(240f, 350f), new Vector2(340f, 380f));

            _wheelieText = UiFactory.Label(root, "WheelieState", "", 24, TextAnchor.MiddleRight, accent,
                new Vector2(0.5f, 0f), new Vector2(0.5f, 0f), new Vector2(-560f, 350f), new Vector2(-240f, 380f));

            // trick popup (appears above the wheelie gauge)
            _trickPopup = UiFactory.Label(root, "TrickPopup", "", 38, TextAnchor.MiddleCenter, accent,
                new Vector2(0.5f, 0f), new Vector2(0.5f, 0f), new Vector2(-520f, 400f), new Vector2(520f, 460f));
        }

        public void ShowTrick(string name, int points)
        {
            if (_trickPopup == null) return;
            _trickPopup.text = name.ToUpperInvariant() + "   +" + points;
            _trickTimer = 1.5f;
        }

        public void ShowBanner(string message, float seconds)
        {
            if (_bannerText == null) return;
            _bannerText.text = message;
            _bannerTimer = seconds;
            _bannerDuration = seconds;
        }

        public void Tick(ScooterController scooter, GameRoot root)
        {
            if (scooter == null || scooter.Spec == null) return;

            if (_speedText != null)
            {
                _speedText.text = Mathf.RoundToInt(scooter.SpeedKmh).ToString();
                float ratio = scooter.MaxSpeedKmh > 0f ? scooter.SpeedKmh / scooter.MaxSpeedKmh : 0f;
                _speedText.color = ratio > 0.92f ? UiFactory.Hex("#FF5A3C") : new Color(0.96f, 0.97f, 0.99f);
            }

            if (_batteryText != null)
            {
                float percent = scooter.BatteryPercent;
                _batteryText.text = Mathf.RoundToInt(percent) + "%";
                UiFactory.SetBar(_batteryFill, percent / 100f);
                if (_batteryFillImage != null)
                {
                    _batteryFillImage.color = percent < 20f
                        ? UiFactory.Hex("#FF4B2B")
                        : (percent < 50f ? UiFactory.Hex("#FFB020") : UiFactory.Hex("#38D66B"));
                }
            }

            if (_modeText != null)
            {
                _modeText.text = "РЕЖИМ " + (scooter.SpeedMode + 1) + " · " +
                                 Mathf.RoundToInt(scooter.Spec.GearTopSpeedKmh(scooter.SpeedMode)) + " КМ/Ч";
            }

            if (_driveText != null)
            {
                _driveText.text = scooter.Drive == DriveMode.AWD ? "AWD" : "RWD";
                _driveText.color = scooter.Drive == DriveMode.AWD ? UiFactory.Hex("#FF7318") : UiFactory.Hex("#8FB6D9");
            }

            if (_distanceText != null)
            {
                _distanceText.text = scooter.DistanceKm.ToString("0.00") + " КМ";
            }

            if (_timeText != null)
            {
                _timeText.text = FormatTime(scooter.RunTime);
            }

            if (root != null)
            {
                if (_scoreText != null) _scoreText.text = root.Score.ToString();
                if (_comboText != null)
                {
                    int combo = root.Combo;
                    _comboText.text = combo > 1 ? ("КОМБО x" + combo + "  (" + root.ComboMultiplier.ToString("0.0") + "x)") : string.Empty;
                }
            }

            if (_wheelieFill != null)
            {
                float pitch = Mathf.Clamp(scooter.PitchAngle, 0f, 80f);
                UiFactory.SetBar(_wheelieFill, pitch / 80f);
            }

            if (_pitchText != null)
            {
                _pitchText.text = Mathf.RoundToInt(scooter.PitchAngle) + "°";
            }

            if (_wheelieText != null)
            {
                if (scooter.IsCrashed) _wheelieText.text = "ПАДЕНИЕ";
                else if (scooter.WheelieInBalanceZone) _wheelieText.text = "БАЛАНС";
                else if (scooter.WheelieActive) _wheelieText.text = scooter.PitchAngle > 55f ? "ОПАСНО" : "ПОДЪЁМ";
                else _wheelieText.text = string.Empty;
            }

            if (_trickPopup != null && _trickTimer > 0f)
            {
                _trickTimer -= Time.deltaTime;
                Color trickColor = _trickPopup.color;
                trickColor.a = Mathf.Clamp01(_trickTimer / 0.7f);
                _trickPopup.color = trickColor;
                if (_trickTimer <= 0f) _trickPopup.text = string.Empty;
            }

            if (_bannerText != null && _bannerTimer > 0f)
            {
                _bannerTimer -= Time.deltaTime;
                float alpha = _bannerDuration > 0f ? Mathf.Clamp01(_bannerTimer / Mathf.Max(0.01f, _bannerDuration * 0.4f)) : 1f;
                Color c = _bannerText.color;
                c.a = Mathf.Clamp01(alpha);
                _bannerText.color = c;
                if (_bannerTimer <= 0f) _bannerText.text = string.Empty;
            }
        }

        public static string FormatTime(float seconds)
        {
            if (seconds < 0f) seconds = 0f;
            int total = Mathf.FloorToInt(seconds);
            int minutes = total / 60;
            int secs = total % 60;
            return minutes.ToString("00") + ":" + secs.ToString("00");
        }
    }
}
