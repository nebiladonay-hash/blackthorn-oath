using System;
using UnityEngine;

namespace BlackthornOath
{
    public sealed class RunGameManager : MonoBehaviour
    {
        public enum RunState
        {
            Title,
            Running,
            Paused,
            GameOver
        }

        public static RunGameManager Instance { get; private set; }

        [SerializeField] private RunnerPlayerController player;
        [SerializeField] private float initialSpeed = 12f;
        [SerializeField] private float speedAcceleration = 0.14f;
        [SerializeField] private float maximumSpeed = 18.5f;

        public event Action StatsChanged;
        public event Action RunEnded;

        public RunState State { get; private set; } = RunState.Title;
        public float Distance { get; private set; }
        public int Kills { get; private set; }
        public int Relics { get; private set; }
        public int RelicBank { get; private set; }
        public int BestDistance { get; private set; }

        private float runStartedAt;
        private float playerStartZ = -3f;

        private const string BestDistanceKey = "blackthorn.best_distance";
        private const string RelicBankKey = "blackthorn.relic_bank";

        private void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }

            Instance = this;
            if (player == null)
                player = FindFirstObjectByType<RunnerPlayerController>();
            BindPlayerDeathEvent();

            BestDistance = PlayerPrefs.GetInt(BestDistanceKey, 0);
            RelicBank = PlayerPrefs.GetInt(RelicBankKey, 0);
        }

        private void Update()
        {
            if (State != RunState.Running || player == null)
                return;

            float elapsed = Time.time - runStartedAt;
            player.SetForwardSpeed(Mathf.Min(initialSpeed + elapsed * speedAcceleration, maximumSpeed));
            Distance = Mathf.Max(Distance, Mathf.Max(0f, -player.transform.position.z + playerStartZ));
            StatsChanged?.Invoke();
        }

        public void BeginRun()
        {
            if (player == null)
                player = FindFirstObjectByType<RunnerPlayerController>();
            BindPlayerDeathEvent();
            if (player == null)
            {
                Debug.LogError("Blackthorn Oath: no RunnerPlayerController is assigned.");
                return;
            }

            Time.timeScale = 1f;
            Distance = 0f;
            Kills = 0;
            Relics = 0;
            player.ResetForRun();
            playerStartZ = player.transform.position.z;
            runStartedAt = Time.time;
            State = RunState.Running;
            StatsChanged?.Invoke();
        }

        public void PauseRun()
        {
            if (State != RunState.Running)
                return;

            State = RunState.Paused;
            Time.timeScale = 0f;
        }

        public void ResumeRun()
        {
            if (State != RunState.Paused)
                return;

            Time.timeScale = 1f;
            State = RunState.Running;
        }

        public void EndRun()
        {
            if (State != RunState.Running && State != RunState.Paused)
                return;

            Time.timeScale = 1f;
            State = RunState.GameOver;
            BestDistance = Mathf.Max(BestDistance, Mathf.FloorToInt(Distance));
            SaveProgress();
            StatsChanged?.Invoke();
            RunEnded?.Invoke();
        }

        public void AddKill()
        {
            Kills++;
            StatsChanged?.Invoke();
        }

        public void AddRelic()
        {
            Relics++;
            RelicBank++;
            SaveProgress();
            StatsChanged?.Invoke();
        }

        public void SaveProgress()
        {
            PlayerPrefs.SetInt(BestDistanceKey, BestDistance);
            PlayerPrefs.SetInt(RelicBankKey, RelicBank);
            PlayerPrefs.Save();
        }

        private void BindPlayerDeathEvent()
        {
            if (player == null)
                return;
            player.Died -= EndRun;
            player.Died += EndRun;
        }

        private void OnDestroy()
        {
            if (Instance == this)
            {
                if (player != null)
                    player.Died -= EndRun;
                Time.timeScale = 1f;
                Instance = null;
            }
        }
    }
}
