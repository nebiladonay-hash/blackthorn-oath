using UnityEngine;

namespace BlackthornOath
{
    public sealed class EnemyCombatant : MonoBehaviour
    {
        public enum Archetype
        {
            HollowGuard,
            Bloodhound,
            Executioner
        }

        [SerializeField] private Archetype archetype = Archetype.HollowGuard;
        [SerializeField] private RunnerPlayerController player;
        [SerializeField] private Animator animator;
        [SerializeField] private string attackTrigger = "Attack";
        [SerializeField] private string hitTrigger = "Hit";
        [SerializeField] private string deathTrigger = "Die";

        public bool IsDead { get; private set; }
        public int Health { get; private set; }

        private float attackInterval;
        private float attackCooldown;
        private float windupRemaining;

        private void Awake()
        {
            Configure(archetype);
            if (player == null)
                player = FindFirstObjectByType<RunnerPlayerController>();
        }

        private void Update()
        {
            if (IsDead || player == null || player.IsDead)
                return;

            float delta = Time.deltaTime;
            attackCooldown = Mathf.Max(0f, attackCooldown - delta);

            Vector3 toPlayer = player.transform.position - transform.position;
            Vector3 flatDirection = new Vector3(toPlayer.x, 0f, toPlayer.z);
            if (flatDirection.sqrMagnitude > 0.001f)
                transform.rotation = Quaternion.Slerp(transform.rotation, Quaternion.LookRotation(flatDirection), delta * 7f);

            bool inRange = Mathf.Abs(toPlayer.z) < 1.9f && Mathf.Abs(toPlayer.x) < 1.05f;
            if (!inRange || attackCooldown > 0f)
            {
                windupRemaining = 0f;
                return;
            }

            if (windupRemaining <= 0f)
            {
                windupRemaining = 0.3f;
                SetTrigger(attackTrigger);
                return;
            }

            windupRemaining -= delta;
            if (windupRemaining <= 0.12f && windupRemaining > 0f)
                return;

            if (windupRemaining <= 0f)
            {
                player.TakeDamage(1);
                AudioDirector.Instance?.PlayEnemyAttack(transform.position);
                attackCooldown = attackInterval;
            }
        }

        public void Configure(Archetype type)
        {
            archetype = type;
            switch (archetype)
            {
                case Archetype.Bloodhound:
                    Health = 1;
                    attackInterval = 0.85f;
                    break;
                case Archetype.Executioner:
                    Health = 3;
                    attackInterval = 1.75f;
                    break;
                default:
                    Health = 2;
                    attackInterval = 1.3f;
                    break;
            }
        }

        public void TakeDamage(int amount = 1)
        {
            if (IsDead)
                return;

            Health -= Mathf.Max(1, amount);
            SetTrigger(hitTrigger);
            AudioDirector.Instance?.PlayEnemyHit(transform.position);

            if (Health <= 0)
            {
                IsDead = true;
                SetTrigger(deathTrigger);
                RunGameManager.Instance?.AddKill();
                AudioDirector.Instance?.PlayEnemyDeath(transform.position);
                Collider[] colliders = GetComponentsInChildren<Collider>();
                foreach (Collider item in colliders)
                    item.enabled = false;
                Destroy(gameObject, 1.4f);
            }
        }

        private void SetTrigger(string triggerName)
        {
            if (animator == null || string.IsNullOrEmpty(triggerName))
                return;

            foreach (AnimatorControllerParameter parameter in animator.parameters)
            {
                if (parameter.name == triggerName && parameter.type == AnimatorControllerParameterType.Trigger)
                {
                    animator.SetTrigger(triggerName);
                    return;
                }
            }
        }
    }
}
