using System;
using UnityEngine;

namespace ScooterGame
{
    /// <summary>On-screen controls for Android: steering, gas, both brakes, wheelie, lean, drive and gear.</summary>
    public class TouchControls : MonoBehaviour
    {
        HoldButton _gas;
        HoldButton _brakeRear;
        HoldButton _brakeFront;
        HoldButton _wheelie;
        HoldButton _steerLeft;
        HoldButton _steerRight;
        HoldButton _leanBack;
        HoldButton _leanForward;

        public static TouchControls Create(Transform canvas, Action onDriveToggle, Action onSpeedMode,
            Action onRespawn, Action onMenu)
        {
            GameObject go = new GameObject("TouchControls", typeof(RectTransform));
            RectTransform root = go.GetComponent<RectTransform>();
            root.SetParent(canvas, false);
            root.anchorMin = Vector2.zero;
            root.anchorMax = Vector2.one;
            root.offsetMin = Vector2.zero;
            root.offsetMax = Vector2.zero;

            TouchControls controls = go.AddComponent<TouchControls>();

            Color padColor = new Color(0.08f, 0.09f, 0.11f, 0.55f);
            Color textColor = new Color(0.95f, 0.96f, 0.98f, 0.92f);
            Color accent = new Color(0.95f, 0.45f, 0.08f, 0.62f);
            Color brakeColor = new Color(0.65f, 0.12f, 0.1f, 0.55f);

            // ---- steering (bottom left) ----
            controls._steerLeft = UiFactory.Hold(root, "SteerLeft", "◀", 58,
                Vector2.zero, Vector2.zero, new Vector2(30f, 40f), new Vector2(170f, 180f), padColor, textColor);
            controls._steerRight = UiFactory.Hold(root, "SteerRight", "▶", 58,
                Vector2.zero, Vector2.zero, new Vector2(190f, 40f), new Vector2(330f, 180f), padColor, textColor);

            controls._leanForward = UiFactory.Hold(root, "LeanForward", "НОС ↓", 26,
                Vector2.zero, Vector2.zero, new Vector2(30f, 200f), new Vector2(170f, 275f), padColor, textColor);
            controls._leanBack = UiFactory.Hold(root, "LeanBack", "НОС ↑", 26,
                Vector2.zero, Vector2.zero, new Vector2(190f, 200f), new Vector2(330f, 275f), padColor, textColor);

            // ---- gas / brakes / wheelie (bottom right, anchored to the right edge) ----
            controls._brakeRear = UiFactory.Hold(root, "BrakeRear", "ЗАД.\nТОРМОЗ", 26,
                new Vector2(1f, 0f), new Vector2(1f, 0f), new Vector2(-430f, 40f), new Vector2(-260f, 170f),
                brakeColor, textColor);
            controls._brakeFront = UiFactory.Hold(root, "BrakeFront", "ПЕРЕД.\nТОРМОЗ", 26,
                new Vector2(1f, 0f), new Vector2(1f, 0f), new Vector2(-430f, 190f), new Vector2(-260f, 320f),
                brakeColor, textColor);
            controls._gas = UiFactory.Hold(root, "Gas", "ГАЗ", 46,
                new Vector2(1f, 0f), new Vector2(1f, 0f), new Vector2(-240f, 40f), new Vector2(-50f, 230f),
                accent, Color.white);
            controls._wheelie = UiFactory.Hold(root, "Wheelie", "WHEELIE", 28,
                new Vector2(1f, 0f), new Vector2(1f, 0f), new Vector2(-240f, 250f), new Vector2(-50f, 360f),
                new Color(0.16f, 0.4f, 0.62f, 0.6f), Color.white);

            // ---- small system buttons (top right, above the stats) ----
            UiFactory.TextButton(root, "DriveButton", "ПРИВОД", 22,
                new Vector2(1f, 1f), new Vector2(1f, 1f), new Vector2(-250f, -92f), new Vector2(-140f, -42f),
                new Color(0.1f, 0.12f, 0.16f, 0.75f), textColor, () => { if (onDriveToggle != null) onDriveToggle(); });

            UiFactory.TextButton(root, "SpeedModeButton", "РЕЖИМ", 22,
                new Vector2(1f, 1f), new Vector2(1f, 1f), new Vector2(-130f, -92f), new Vector2(-20f, -42f),
                new Color(0.1f, 0.12f, 0.16f, 0.75f), textColor, () => { if (onSpeedMode != null) onSpeedMode(); });

            UiFactory.TextButton(root, "MenuButton", "МЕНЮ", 20,
                new Vector2(1f, 1f), new Vector2(1f, 1f), new Vector2(-130f, -148f), new Vector2(-20f, -102f),
                new Color(0.1f, 0.12f, 0.16f, 0.75f), textColor, () => { if (onMenu != null) onMenu(); });

            UiFactory.TextButton(root, "RespawnButton", "СБРОС", 20,
                new Vector2(1f, 1f), new Vector2(1f, 1f), new Vector2(-250f, -148f), new Vector2(-140f, -102f),
                new Color(0.1f, 0.12f, 0.16f, 0.75f), textColor, () => { if (onRespawn != null) onRespawn(); });

            return controls;
        }

        void Update()
        {
            TouchState.Throttle = _gas != null && _gas.IsHeld ? 1f : 0f;
            TouchState.BrakeRear = _brakeRear != null && _brakeRear.IsHeld ? 1f : 0f;
            TouchState.BrakeFront = _brakeFront != null && _brakeFront.IsHeld ? 1f : 0f;

            float steer = 0f;
            if (_steerLeft != null && _steerLeft.IsHeld) steer -= 1f;
            if (_steerRight != null && _steerRight.IsHeld) steer += 1f;
            TouchState.Steer = steer;

            float lean = 0f;
            if (_leanBack != null && _leanBack.IsHeld) lean += 1f;
            if (_leanForward != null && _leanForward.IsHeld) lean -= 1f;
            TouchState.BodyPitch = lean;

            TouchState.Wheelie = _wheelie != null && _wheelie.IsHeld;
        }

        void OnDestroy()
        {
            TouchState.ClearAll();
        }
    }
}
