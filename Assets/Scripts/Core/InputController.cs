using UnityEngine;

namespace ScooterGame
{
    /// <summary>Merged input state read by the vehicle each FixedUpdate.</summary>
    public static class PlayerInput
    {
        public static float Throttle;
        public static float BrakeFront;
        public static float BrakeRear;
        public static float Steer;
        public static float BodyPitch;   // +1 lean back / lift, -1 lean forward
        public static bool Wheelie;

        public static bool DriveTogglePressed;
        public static bool SpeedModePressed;
        public static int SpeedModeRequest = -1;
        public static bool RespawnPressed;
        public static bool MenuPressed;

        public static void ResetAll()
        {
            Throttle = 0f;
            BrakeFront = 0f;
            BrakeRear = 0f;
            Steer = 0f;
            BodyPitch = 0f;
            Wheelie = false;
            DriveTogglePressed = false;
            SpeedModePressed = false;
            SpeedModeRequest = -1;
            RespawnPressed = false;
            MenuPressed = false;
        }

        public static bool ConsumeDriveToggle()
        {
            bool value = DriveTogglePressed;
            DriveTogglePressed = false;
            return value;
        }

        public static int ConsumeSpeedModeRequest()
        {
            int value = SpeedModeRequest;
            SpeedModeRequest = -1;
            return value;
        }

        public static bool ConsumeRespawn()
        {
            bool value = RespawnPressed;
            RespawnPressed = false;
            return value;
        }

        public static bool ConsumeMenu()
        {
            bool value = MenuPressed;
            MenuPressed = false;
            return value;
        }
    }

    /// <summary>Values written by the on-screen touch pad. Combined with the keyboard in <see cref="InputController"/>.</summary>
    public static class TouchState
    {
        public static float Throttle;
        public static float BrakeFront;
        public static float BrakeRear;
        public static float Steer;
        public static float BodyPitch;
        public static bool Wheelie;
        public static bool DriveToggleEdge;
        public static bool SpeedModeEdge;

        public static void ClearValues()
        {
            Throttle = 0f;
            BrakeFront = 0f;
            BrakeRear = 0f;
            Steer = 0f;
            BodyPitch = 0f;
            Wheelie = false;
        }

        public static void ClearAll()
        {
            ClearValues();
            DriveToggleEdge = false;
            SpeedModeEdge = false;
        }

        public static void ClearEdges()
        {
            DriveToggleEdge = false;
            SpeedModeEdge = false;
        }
    }

    /// <summary>Polls the keyboard and merges it with the touch pad values every frame.</summary>
    public class InputController : MonoBehaviour
    {
        public static InputController Instance { get; private set; }

        void Awake()
        {
            Instance = this;
        }

        void Update()
        {
            float keyboardThrottle = (Input.GetKey(KeyCode.W) || Input.GetKey(KeyCode.UpArrow)) ? 1f : 0f;
            float keyboardRearBrake = (Input.GetKey(KeyCode.S) || Input.GetKey(KeyCode.DownArrow)) ? 1f : 0f;
            float keyboardFrontBrake = Input.GetKey(KeyCode.LeftShift) ? 1f : 0f;

            float steer = 0f;
            if (Input.GetKey(KeyCode.A) || Input.GetKey(KeyCode.LeftArrow)) steer -= 1f;
            if (Input.GetKey(KeyCode.D) || Input.GetKey(KeyCode.RightArrow)) steer += 1f;

            float bodyPitch = 0f;
            if (Input.GetKey(KeyCode.Q)) bodyPitch += 1f;
            if (Input.GetKey(KeyCode.E)) bodyPitch -= 1f;

            bool wheelie = Input.GetKey(KeyCode.Space) || Input.GetKey(KeyCode.LeftControl);

            PlayerInput.Throttle = Mathf.Clamp01(Mathf.Max(keyboardThrottle, TouchState.Throttle));
            PlayerInput.BrakeRear = Mathf.Clamp01(Mathf.Max(keyboardRearBrake, TouchState.BrakeRear));
            PlayerInput.BrakeFront = Mathf.Clamp01(Mathf.Max(keyboardFrontBrake, TouchState.BrakeFront));
            PlayerInput.Steer = Mathf.Clamp(steer + TouchState.Steer, -1f, 1f);
            PlayerInput.BodyPitch = Mathf.Clamp(bodyPitch + TouchState.BodyPitch, -1f, 1f);
            PlayerInput.Wheelie = wheelie || TouchState.Wheelie;

            if (Input.GetKeyDown(KeyCode.Tab) || TouchState.DriveToggleEdge)
            {
                PlayerInput.DriveTogglePressed = true;
            }

            if (TouchState.SpeedModeEdge)
            {
                PlayerInput.SpeedModePressed = true;
            }

            if (Input.GetKeyDown(KeyCode.Alpha1)) PlayerInput.SpeedModeRequest = 0;
            if (Input.GetKeyDown(KeyCode.Alpha2)) PlayerInput.SpeedModeRequest = 1;
            if (Input.GetKeyDown(KeyCode.Alpha3)) PlayerInput.SpeedModeRequest = 2;
            if (Input.GetKeyDown(KeyCode.R)) PlayerInput.RespawnPressed = true;
            if (Input.GetKeyDown(KeyCode.Escape)) PlayerInput.MenuPressed = true;

            TouchState.ClearEdges();
        }
    }
}
