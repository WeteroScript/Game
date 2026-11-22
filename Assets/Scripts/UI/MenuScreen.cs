using System;
using UnityEngine;
using UnityEngine.UI;

namespace ScooterGame
{
    /// <summary>
    /// Start screen: pick a scooter (both are free), a map and a game mode.
    /// </summary>
    public class MenuScreen : MonoBehaviour
    {
        Action<string, MapId, GameMode> _onStart;

        Image _cardG4;
        Image _cardF3;
        Button _mapStraight;
        Button _mapCity;
        Button _modeFree;
        Button _modeTime;
        Button _modeFreestyle;

        int _scooterIndex;
        MapId _map = MapId.StraightTrack;
        GameMode _mode = GameMode.FreeRide;

        public static MenuScreen Create(Transform parent, Action<string, MapId, GameMode> onStart)
        {
            GameObject go = new GameObject("MenuScreen", typeof(RectTransform));
            RectTransform root = go.GetComponent<RectTransform>();
            root.SetParent(parent, false);
            root.anchorMin = Vector2.zero;
            root.anchorMax = Vector2.one;
            root.offsetMin = Vector2.zero;
            root.offsetMax = Vector2.zero;

            MenuScreen menu = go.AddComponent<MenuScreen>();
            menu._onStart = onStart;
            menu.Build(root);
            return menu;
        }

        void Build(RectTransform root)
        {
            Color white = new Color(0.96f, 0.97f, 0.99f);
            Color dim = new Color(0.7f, 0.74f, 0.8f);
            Color accent = UiFactory.Hex("#FF7318");

            UiFactory.Panel(root, "Background", new Color(0.035f, 0.04f, 0.055f, 0.97f),
                Vector2.zero, Vector2.one, Vector2.zero, Vector2.zero);

            UiFactory.Label(root, "Title", "KUGOO FREERIDE", 88, TextAnchor.MiddleCenter, white,
                new Vector2(0.5f, 1f), new Vector2(0.5f, 1f), new Vector2(-700f, -150f), new Vector2(700f, -40f));

            UiFactory.Label(root, "Subtitle", "симулятор электросамоката · wheelie · трюки · две карты", 28,
                TextAnchor.MiddleCenter, accent,
                new Vector2(0.5f, 1f), new Vector2(0.5f, 1f), new Vector2(-700f, -196f), new Vector2(700f, -158f));

            // ---- scooter cards ----
            _cardG4 = BuildCard(root, 0, 100f, 900f, "KugooKirin G4", "2026 · задний привод RWD",
                "• 2000 Вт (пик 2400 Вт), один задний хаб-мотор\n" +
                "• 70 км/ч · режимы 20 / 40 / 70\n" +
                "• 60V 20Ah · до 75 км\n" +
                "• 11\" внедорожные пневматические\n" +
                "• 37 кг · нагрузка 120 кг\n" +
                "• два дисковых тормоза, двойная подвеска\n" +
                "• LCD, фара, стоп-сигнал, поворотники, ключ");

            _cardF3 = BuildCard(root, 1, 1020f, 1820f, "Kugoo F3 Pro Max", "полный привод AWD ⇄ RWD",
                "• 2 × 1100 Вт = 2200 Вт, два хаб-мотора\n" +
                "• 68 км/ч · режимы 30 / 51 / 66\n" +
                "• 52V 23.4Ah · до 70 км\n" +
                "• 10\" бескамерные пневматические\n" +
                "• 32.5 кг · нагрузка 130 кг\n" +
                "• дисковые + электронный тормоз, амортизация\n" +
                "• LCD, переключатель AWD/RWD, фара, габариты");

            // ---- map row ----
            UiFactory.Label(root, "MapCaption", "КАРТА", 26, TextAnchor.MiddleRight, dim,
                new Vector2(0.5f, 0f), new Vector2(0.5f, 0f), new Vector2(-660f, 244f), new Vector2(-480f, 306f));

            _mapStraight = UiFactory.TextButton(root, "MapStraight", "ПРЯМАЯ ТРАССА", 26,
                new Vector2(0.5f, 0f), new Vector2(0.5f, 0f), new Vector2(-460f, 244f), new Vector2(-120f, 306f),
                new Color(0.1f, 0.12f, 0.16f, 0.9f), white, () => { _map = MapId.StraightTrack; Refresh(); });

            _mapCity = UiFactory.TextButton(root, "MapCity", "ГОРОД", 26,
                new Vector2(0.5f, 0f), new Vector2(0.5f, 0f), new Vector2(-100f, 244f), new Vector2(240f, 306f),
                new Color(0.1f, 0.12f, 0.16f, 0.9f), white, () => { _map = MapId.City; Refresh(); });

            // ---- mode row ----
            UiFactory.Label(root, "ModeCaption", "РЕЖИМ", 26, TextAnchor.MiddleRight, dim,
                new Vector2(0.5f, 0f), new Vector2(0.5f, 0f), new Vector2(-660f, 174f), new Vector2(-480f, 236f));

            _modeFree = UiFactory.TextButton(root, "ModeFree", "СВОБОДНАЯ ЕЗДА", 24,
                new Vector2(0.5f, 0f), new Vector2(0.5f, 0f), new Vector2(-460f, 174f), new Vector2(-160f, 236f),
                new Color(0.1f, 0.12f, 0.16f, 0.9f), white, () => { _mode = GameMode.FreeRide; Refresh(); });

            _modeTime = UiFactory.TextButton(root, "ModeTime", "TIME ATTACK", 24,
                new Vector2(0.5f, 0f), new Vector2(0.5f, 0f), new Vector2(-140f, 174f), new Vector2(100f, 236f),
                new Color(0.1f, 0.12f, 0.16f, 0.9f), white, () => { _mode = GameMode.TimeAttack; Refresh(); });

            _modeFreestyle = UiFactory.TextButton(root, "ModeFreestyle", "FREESTYLE", 24,
                new Vector2(0.5f, 0f), new Vector2(0.5f, 0f), new Vector2(120f, 174f), new Vector2(360f, 236f),
                new Color(0.1f, 0.12f, 0.16f, 0.9f), white, () => { _mode = GameMode.Freestyle; Refresh(); });

            // ---- start ----
            UiFactory.TextButton(root, "StartButton", "СТАРТ", 44,
                new Vector2(0.5f, 0f), new Vector2(0.5f, 0f), new Vector2(-260f, 50f), new Vector2(260f, 150f),
                accent, Color.white, () =>
                {
                    ScooterSpec[] specs = ScooterSpec.All();
                    ScooterSpec selected = specs[Mathf.Clamp(_scooterIndex, 0, specs.Length - 1)];
                    if (_onStart != null) _onStart(selected.Id, _map, _mode);
                });

            UiFactory.Label(root, "FreeNote", "оба самоката доступны сразу — бесплатно, без доната и покупок", 22,
                TextAnchor.MiddleCenter, UiFactory.Hex("#8FE0A8"),
                new Vector2(0.5f, 0f), new Vector2(0.5f, 0f), new Vector2(-700f, 8f), new Vector2(700f, 42f));

            Refresh();
        }

        Image BuildCard(RectTransform root, int index, float left, float right, string title, string tagline, string specs)
        {
            Image card = UiFactory.Panel(root, "Card_" + index, new Color(0.07f, 0.08f, 0.1f, 0.95f),
                new Vector2(0f, 0.5f), new Vector2(0f, 0.5f), new Vector2(left, -150f), new Vector2(right, 250f));
            card.raycastTarget = true;

            Button button = card.gameObject.AddComponent<Button>();
            button.targetGraphic = card;
            int captured = index;
            button.onClick.AddListener(() => { _scooterIndex = captured; Refresh(); });

            // accent strip
            UiFactory.Panel(card.transform, "Accent", UiFactory.Hex("#FF7318"),
                new Vector2(0f, 0f), new Vector2(0f, 1f), new Vector2(0f, 0f), new Vector2(8f, 0f));

            UiFactory.Label(card.transform, "Title", title, 46, TextAnchor.UpperLeft,
                new Color(0.96f, 0.97f, 0.99f),
                new Vector2(0f, 1f), new Vector2(1f, 1f), new Vector2(34f, -74f), new Vector2(-30f, -18f));

            UiFactory.Label(card.transform, "Tagline", tagline, 26, TextAnchor.UpperLeft, UiFactory.Hex("#FFB067"),
                new Vector2(0f, 1f), new Vector2(1f, 1f), new Vector2(34f, -112f), new Vector2(-30f, -78f));

            UiFactory.Label(card.transform, "Specs", specs, 23, TextAnchor.UpperLeft, new Color(0.78f, 0.82f, 0.88f),
                new Vector2(0f, 0f), new Vector2(1f, 1f), new Vector2(34f, 56f), new Vector2(-30f, -120f));

            UiFactory.Label(card.transform, "Free", "БЕСПЛАТНО", 22, TextAnchor.MiddleRight, UiFactory.Hex("#8FE0A8"),
                new Vector2(0f, 0f), new Vector2(1f, 0f), new Vector2(-260f, 14f), new Vector2(-30f, 48f));

            UiFactory.Label(card.transform, "Pick", "НАЖМИТЕ, ЧТОБЫ ВЫБРАТЬ", 20, TextAnchor.MiddleLeft,
                new Color(0.6f, 0.64f, 0.7f),
                new Vector2(0f, 0f), new Vector2(1f, 0f), new Vector2(34f, 14f), new Vector2(-260f, 48f));

            return card;
        }

        void Refresh()
        {
            Color selectedCard = new Color(0.12f, 0.14f, 0.18f, 0.98f);
            Color idleCard = new Color(0.06f, 0.07f, 0.09f, 0.92f);
            if (_cardG4 != null) _cardG4.color = _scooterIndex == 0 ? selectedCard : idleCard;
            if (_cardF3 != null) _cardF3.color = _scooterIndex == 1 ? selectedCard : idleCard;

            Color selectedButton = UiFactory.Hex("#FF7318");
            Color idleButton = new Color(0.1f, 0.12f, 0.16f, 0.9f);

            SetButtonColor(_mapStraight, _map == MapId.StraightTrack ? selectedButton : idleButton);
            SetButtonColor(_mapCity, _map == MapId.City ? selectedButton : idleButton);

            SetButtonColor(_modeFree, _mode == GameMode.FreeRide ? selectedButton : idleButton);
            SetButtonColor(_modeTime, _mode == GameMode.TimeAttack ? selectedButton : idleButton);
            SetButtonColor(_modeFreestyle, _mode == GameMode.Freestyle ? selectedButton : idleButton);
        }

        static void SetButtonColor(Button button, Color color)
        {
            if (button == null) return;
            Image image = button.GetComponent<Image>();
            if (image != null) image.color = color;
            ColorBlock colors = button.colors;
            colors.normalColor = Color.white;
            button.colors = colors;
        }

        public void Show()
        {
            gameObject.SetActive(true);
            Refresh();
        }

        public void Hide()
        {
            gameObject.SetActive(false);
        }

        public bool IsVisible { get { return gameObject.activeSelf; } }
    }
}
