using UnityEngine;
using UnityEngine.Audio;

namespace BlackthornOath
{
    public sealed class AudioDirector : MonoBehaviour
    {
        public static AudioDirector Instance { get; private set; }

        [Header("Sources")]
        [SerializeField] private AudioSource musicSource;
        [SerializeField] private AudioSource effectsSource;
        [SerializeField] private AudioSource uiSource;
        [SerializeField] private AudioMixerGroup musicBus;
        [SerializeField] private AudioMixerGroup effectsBus;
        [SerializeField] private AudioMixerGroup uiBus;

        [Header("Music")]
        [SerializeField] private AudioClip titleAndWorldAmbience;

        [Header("Player")]
        [SerializeField] private AudioClip[] footsteps;
        [SerializeField] private AudioClip jump;
        [SerializeField] private AudioClip slide;
        [SerializeField] private AudioClip swordSwing;
        [SerializeField] private AudioClip playerHit;

        [Header("Combat")]
        [SerializeField] private AudioClip[] enemyAttacks;
        [SerializeField] private AudioClip[] enemyImpacts;
        [SerializeField] private AudioClip[] enemyDeaths;
        [SerializeField] private AudioClip relicPickup;

        [Header("Interface")]
        [SerializeField] private AudioClip uiConfirm;
        [SerializeField] private AudioClip uiBack;

        private void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }

            Instance = this;
            DontDestroyOnLoad(gameObject);
            ConfigureSource(musicSource, musicBus);
            ConfigureSource(effectsSource, effectsBus);
            ConfigureSource(uiSource, uiBus);

            if (musicSource != null && titleAndWorldAmbience != null)
            {
                musicSource.clip = titleAndWorldAmbience;
                musicSource.loop = true;
                musicSource.volume = 0.72f;
                musicSource.Play();
            }
        }

        public void PlayFootstep()
        {
            PlayOneShot(effectsSource, footsteps, 0.55f, 0.94f, 1.06f);
        }

        public void PlayJump() => PlayOneShot(effectsSource, jump, 0.7f, 0.96f, 1.04f);
        public void PlaySlide() => PlayOneShot(effectsSource, slide, 0.65f, 0.96f, 1.04f);
        public void PlaySwordSwing() => PlayOneShot(effectsSource, swordSwing, 0.8f, 0.92f, 1.08f);
        public void PlayPlayerHit() => PlayOneShot(effectsSource, playerHit, 0.9f, 0.96f, 1.04f);
        public void PlayUiConfirm() => PlayOneShot(uiSource, uiConfirm, 0.7f, 0.98f, 1.02f);
        public void PlayUiBack() => PlayOneShot(uiSource, uiBack, 0.65f, 0.98f, 1.02f);

        public void PlayEnemyAttack(Vector3 position) => PlayWorld(enemyAttacks, position, 0.75f);
        public void PlayEnemyHit(Vector3 position) => PlayWorld(enemyImpacts, position, 0.85f);
        public void PlayEnemyDeath(Vector3 position) => PlayWorld(enemyDeaths, position, 0.9f);
        public void PlayRelicPickup(Vector3 position) => PlayWorld(relicPickup, position, 0.75f);

        private static void ConfigureSource(AudioSource source, AudioMixerGroup bus)
        {
            if (source == null)
                return;

            source.outputAudioMixerGroup = bus;
            source.playOnAwake = false;
        }

        private static void PlayOneShot(AudioSource source, AudioClip[] clips, float volume, float pitchMin, float pitchMax)
        {
            if (clips == null || clips.Length == 0)
                return;

            AudioClip clip = clips[Random.Range(0, clips.Length)];
            PlayOneShot(source, clip, volume, pitchMin, pitchMax);
        }

        private static void PlayOneShot(AudioSource source, AudioClip clip, float volume, float pitchMin, float pitchMax)
        {
            if (source == null || clip == null)
                return;

            source.pitch = Random.Range(pitchMin, pitchMax);
            source.PlayOneShot(clip, volume);
            source.pitch = 1f;
        }

        private void PlayWorld(AudioClip[] clips, Vector3 position, float volume)
        {
            if (clips == null || clips.Length == 0)
                return;
            PlayWorld(clips[Random.Range(0, clips.Length)], position, volume);
        }

        private void PlayWorld(AudioClip clip, Vector3 position, float volume)
        {
            if (clip == null)
                return;

            GameObject soundObject = new GameObject("OneShot_3D_Audio");
            soundObject.transform.position = position;
            AudioSource source = soundObject.AddComponent<AudioSource>();
            source.clip = clip;
            source.outputAudioMixerGroup = effectsBus;
            source.spatialBlend = 1f;
            source.rolloffMode = AudioRolloffMode.Linear;
            source.minDistance = 2f;
            source.maxDistance = 24f;
            source.volume = volume;
            source.pitch = Random.Range(0.96f, 1.04f);
            source.Play();
            Destroy(soundObject, clip.length + 0.15f);
        }
    }
}
