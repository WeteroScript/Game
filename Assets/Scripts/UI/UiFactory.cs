using UnityEngine;
using UnityEngine.Events;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace ScooterGame
{
    /// <summary>Builds the whole UI in code (no prefabs, no font assets to import).</summary>
    public static class UiFactory
    {
        static Font _font;

        public static Font DefaultFont
        {
            get
            {
                if (_font != null) return _font;
                try { _font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf"); }
                catch { _font = null; }
                if (_font == null)
                {
                    try { _font = Resources.GetBuiltinResource<Font>("Arial.ttf"); }
                    catch { _font = null; }
                }
                if (_font == null)
                {
                    try { _font = Font.CreateDynamicFontFromOSFont("Roboto", 24); }
                    catch { _font = null; }
                }
                return _font;
            }
        }

        public static Canvas CreateCanvas(string name, int sortOrder)
        {
            GameObject go = new GameObject(name, typeof(RectTransform));
            Canvas canvas = go.AddComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            canvas.sortingOrder = sortOrder;

            CanvasScaler scaler = go.AddComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(1920f, 1080f);
            scaler.screenMatchMode = CanvasScaler.ScreenMatchMode.MatchWidthOrHeight;
            scaler.matchWidthOrHeight = 0.5f;

            go.AddComponent<GraphicRaycaster>();
            return canvas;
        }

        public static void EnsureEventSystem()
        {
            if (Object.FindObjectOfType<EventSystem>() != null) return;
            GameObject go = new GameObject("EventSystem");
            go.AddComponent<EventSystem>();
            go.AddComponent<StandaloneInputModule>();
            Object.DontDestroyOnLoad(go);
        }

        public static RectTransform Rect(Transform parent, string name, Vector2 anchorMin, Vector2 anchorMax,
            Vector2 offsetMin, Vector2 offsetMax)
        {
            GameObject go = new GameObject(name, typeof(RectTransform));
            RectTransform rect = go.GetComponent<RectTransform>();
            rect.SetParent(parent, false);
            rect.anchorMin = anchorMin;
            rect.anchorMax = anchorMax;
            rect.offsetMin = offsetMin;
            rect.offsetMax = offsetMax;
            rect.localScale = Vector3.one;
            rect.localRotation = Quaternion.identity;
            return rect;
        }

        public static Image Panel(Transform parent, string name, Color color, Vector2 anchorMin, Vector2 anchorMax,
            Vector2 offsetMin, Vector2 offsetMax)
        {
            RectTransform rect = Rect(parent, name, anchorMin, anchorMax, offsetMin, offsetMax);
            Image image = rect.gameObject.AddComponent<Image>();
            image.color = color;
            image.raycastTarget = false;
            return image;
        }

        public static Text Label(Transform parent, string name, string content, int size, TextAnchor anchor,
            Color color, Vector2 anchorMin, Vector2 anchorMax, Vector2 offsetMin, Vector2 offsetMax)
        {
            RectTransform rect = Rect(parent, name, anchorMin, anchorMax, offsetMin, offsetMax);
            Text text = rect.gameObject.AddComponent<Text>();
            text.font = DefaultFont;
            text.text = content;
            text.fontSize = size;
            text.alignment = anchor;
            text.color = color;
            text.raycastTarget = false;
            text.horizontalOverflow = HorizontalWrapMode.Overflow;
            text.verticalOverflow = VerticalWrapMode.Overflow;
            text.supportRichText = true;
            return text;
        }

        public static Button TextButton(Transform parent, string name, string content, int fontSize,
            Vector2 anchorMin, Vector2 anchorMax, Vector2 offsetMin, Vector2 offsetMax,
            Color background, Color textColor, UnityAction onClick)
        {
            RectTransform rect = Rect(parent, name, anchorMin, anchorMax, offsetMin, offsetMax);
            Image image = rect.gameObject.AddComponent<Image>();
            image.color = background;

            Button button = rect.gameObject.AddComponent<Button>();
            button.targetGraphic = image;
            ColorBlock colors = button.colors;
            colors.normalColor = Color.white;
            colors.highlightedColor = new Color(1.05f, 1.05f, 1.05f, 1f);
            colors.pressedColor = new Color(0.75f, 0.75f, 0.75f, 1f);
            colors.selectedColor = Color.white;
            colors.fadeDuration = 0.05f;
            button.colors = colors;
            if (onClick != null) button.onClick.AddListener(onClick);

            Text label = Label(rect, "Label", content, fontSize, TextAnchor.MiddleCenter, textColor,
                Vector2.zero, Vector2.one, Vector2.zero, Vector2.zero);
            label.raycastTarget = false;

            return button;
        }

        /// <summary>Round-ish touch button with a hold callback.</summary>
        public static HoldButton Hold(Transform parent, string name, string content, int fontSize,
            Vector2 anchorMin, Vector2 anchorMax, Vector2 offsetMin, Vector2 offsetMax,
            Color background, Color textColor)
        {
            Image image = Panel(parent, name, background, anchorMin, anchorMax, offsetMin, offsetMax);
            image.raycastTarget = true;

            HoldButton hold = image.gameObject.AddComponent<HoldButton>();

            Text label = Label(image.transform, "Label", content, fontSize, TextAnchor.MiddleCenter, textColor,
                Vector2.zero, Vector2.one, Vector2.zero, Vector2.zero);
            label.raycastTarget = false;
            label.horizontalOverflow = HorizontalWrapMode.Wrap;

            return hold;
        }

        /// <summary>Progress bar built from two stretched images (no sprites required).</summary>
        public static RectTransform Bar(Transform parent, string name, Color background, Color fill,
            Vector2 anchorMin, Vector2 anchorMax, Vector2 offsetMin, Vector2 offsetMax, out Image fillImage)
        {
            Image bg = Panel(parent, name, background, anchorMin, anchorMax, offsetMin, offsetMax);

            RectTransform fillRect = Rect(bg.transform, "Fill", Vector2.zero, Vector2.one, Vector2.zero, Vector2.zero);
            fillRect.anchorMin = new Vector2(0f, 0f);
            fillRect.anchorMax = new Vector2(1f, 1f);
            fillRect.offsetMin = new Vector2(0f, 2f);
            fillRect.offsetMax = new Vector2(0f, -2f);

            fillImage = fillRect.gameObject.AddComponent<Image>();
            fillImage.color = fill;
            fillImage.raycastTarget = false;
            return fillRect;
        }

        public static void SetBar(RectTransform fill, float value01)
        {
            if (fill == null) return;
            float v = Mathf.Clamp01(value01);
            fill.anchorMax = new Vector2(v, 1f);
            // width must never go negative (a negative-width rect renders flipped)
            fill.offsetMax = new Vector2(0f, -2f);
        }

        public static Color Hex(string hex)
        {
            Color color;
            if (ColorUtility.TryParseHtmlString(hex, out color)) return color;
            return Color.white;
        }
    }
}
