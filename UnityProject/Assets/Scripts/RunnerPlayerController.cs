using System;
using UnityEngine;

namespace BlackthornOath
{
    [RequireComponent(typeof(CharacterController))]
    public sealed class RunnerPlayerController : MonoBehaviour
    {
        [Header("Movement")]
        [SerializeField] private float laneWidth = 2.6f;
        [SerializeField] private float laneSharpness = 14f;
        [SerializeField] private float jumpVelocity = 10.2f;
        [SerializeField] private float gravity = 25f;
        [SerializeField] private float standingHeight = 1.85f;
        [SerializeField] private float slidingHeight = 0.95f;
        [SerializeField] private float slideDuration = 0.78f;

        [Header("Combat")]
        [SerializeField] private float attackCooldown = 0.58f;
        [SerializeField] private float attackRangeRadius = 2.25f;
        [SerializeField] private LayerMask enemyLayers = ~0;

        [Header("Animation")]
        [SerializeField] private Animator animator;
        [SerializeField] private string runningParameter = "Running";
        [SerializeField] private string jumpingParameter = "Jumping";
        [SerializeField] private string slidingParameter = "Sliding";
        [SerializeField] private string attackTrigger = "Attack";
        [SerializeField] private string hitTrigger = "Hit";
        [SerializeField] private string deathTrigger = "Die";

        public event Action<int> HealthChanged;
        public event Action Died;

        public int Health { get; private set; } = 3;
        public int Lane { get; private set; } = 1;
        public bool IsDead { get; private set; }
        public bool IsInvulnerable => invulnerabilityTimer > 0f;
        public float ForwardSpeed { get; private set; }

        private CharacterController characterController;
        private float verticalVelocity;
        private float laneVelocity;
        private float slideTimer;
        private float attackTimer;
        private float invulnerabilityTimer;
        private float blinkTimer;
        private bool renderersVisible = true;
        private Vector2 swipeStart;
        private bool trackingSwipe;
        private readonly Renderer[] modelRenderers = new Renderer[32];
        private int rendererCount;
        private readonly Collider[] attackHits = new Collider[24];

        private void Awake()
        {
            characterController = GetComponent<CharacterController>();
            characterController.height = standingHeight;
            characterController.center = Vector3.up * (standingHeight * 0.5f);
            CacheModelRenderers();
        }

        private void Update()
        {
            if (IsDead)
                return;

            float delta = Time.deltaTime;
            ReadInput();

            if (attackTimer > 0f)
                attackTimer = Mathf.Max(0f, attackTimer - delta);

            if (invulnerabilityTimer > 0f)
            {
                invulnerabilityTimer = Mathf.Max(0f, invulnerabilityTimer - delta);
                blinkTimer -= delta;
                if (blinkTimer <= 0f)
                {
                    blinkTimer = 0.085f;
                    SetModelVisible(!renderersVisible);
                }
                if (invulnerabilityTimer <= 0f)
                    SetModelVisible(true);
            }

            if (slideTimer > 0f)
            {
                slideTimer = Mathf.Max(0f, slideTimer - delta);
                if (slideTimer <= 0f)
                    SetSliding(false);
            }

            float targetX = (Lane - 1) * laneWidth;
            float nextX = Mathf.SmoothDamp(transform.position.x, targetX, ref laneVelocity, 1f / laneSharpness, Mathf.Infinity, delta);
            float horizontalDelta = nextX - transform.position.x;

            if (characterController.isGrounded && verticalVelocity < 0f)
                verticalVelocity = -1.5f;
            else
                verticalVelocity -= gravity * delta;

            Vector3 motion = new Vector3(horizontalDelta, verticalVelocity * delta, -ForwardSpeed * delta);
            characterController.Move(motion);

            if (characterController.isGrounded && verticalVelocity < 0f)
                verticalVelocity = -1.5f;

            UpdateAnimation();
        }

        private void ReadInput()
        {
            if (Input.GetKeyDown(KeyCode.LeftArrow) || Input.GetKeyDown(KeyCode.A))
                MoveLane(-1);
            if (Input.GetKeyDown(KeyCode.RightArrow) || Input.GetKeyDown(KeyCode.D))
                MoveLane(1);
            if (Input.GetKeyDown(KeyCode.Space) || Input.GetKeyDown(KeyCode.UpArrow))
                Jump();
            if (Input.GetKeyDown(KeyCode.DownArrow) || Input.GetKeyDown(KeyCode.S))
                Slide();
            if (Input.GetKeyDown(KeyCode.F))
                Attack();

            for (int i = 0; i < Input.touchCount; i++)
            {
                Touch touch = Input.GetTouch(i);
                if (touch.phase == TouchPhase.Began)
                {
                    swipeStart = touch.position;
                    trackingSwipe = true;
                }
                else if (touch.phase == TouchPhase.Ended && trackingSwipe)
                {
                    Vector2 swipe = touch.position - swipeStart;
                    trackingSwipe = false;
                    if (swipe.magnitude >= 38f)
                    {
                        if (Mathf.Abs(swipe.x) > Mathf.Abs(swipe.y))
                            MoveLane(swipe.x > 0f ? 1 : -1);
                        else if (swipe.y < 0f)
                            Slide();
                        else
                            Jump();
                    }
                }
                else if (touch.phase == TouchPhase.Canceled)
                {
                    trackingSwipe = false;
                }
            }
        }

        public void SetForwardSpeed(float speed)
        {
            ForwardSpeed = Mathf.Max(0f, speed);
        }

        public void MoveLane(int direction)
        {
            if (IsDead || direction == 0)
                return;
            Lane = Mathf.Clamp(Lane + Math.Sign(direction), 0, 2);
        }

        public void Jump()
        {
            if (IsDead || !characterController.isGrounded || slideTimer > 0f)
                return;

            verticalVelocity = jumpVelocity;
            AudioDirector.Instance?.PlayJump();
            UpdateAnimation();
        }

        public void Slide()
        {
            if (IsDead || !characterController.isGrounded || slideTimer > 0f)
                return;

            slideTimer = slideDuration;
            SetSliding(true);
            AudioDirector.Instance?.PlaySlide();
        }

        private void SetSliding(bool active)
        {
            characterController.height = active ? slidingHeight : standingHeight;
            characterController.center = Vector3.up * (characterController.height * 0.5f);
            SetAnimatorBool(slidingParameter, active);
        }

        public void Attack()
        {
            if (IsDead || attackTimer > 0f || slideTimer > 0f)
                return;

            attackTimer = attackCooldown;
            if (HasAnimatorParameter(attackTrigger, AnimatorControllerParameterType.Trigger))
                animator.SetTrigger(attackTrigger);

            AudioDirector.Instance?.PlaySwordSwing();

            Vector3 center = transform.position + Vector3.up * 1.0f + Vector3.back * 1.35f;
            int count = Physics.OverlapSphereNonAlloc(center, attackRangeRadius, attackHits, enemyLayers, QueryTriggerInteraction.Collide);
            for (int i = 0; i < count; i++)
            {
                Collider hit = attackHits[i];
                if (hit == null)
                    continue;

                EnemyCombatant enemy = hit.GetComponentInParent<EnemyCombatant>();
                if (enemy == null || enemy.IsDead)
                    continue;

                Vector3 difference = enemy.transform.position - transform.position;
                if (Mathf.Abs(difference.x) < 1.5f && difference.z > -3.2f && difference.z < 0.8f)
                    enemy.TakeDamage(1);
            }
            Array.Clear(attackHits, 0, count);
        }

        public void TakeDamage(int amount = 1)
        {
            if (IsDead || invulnerabilityTimer > 0f)
                return;

            Health = Mathf.Max(0, Health - Mathf.Max(1, amount));
            invulnerabilityTimer = 1f;
            blinkTimer = 0f;
            SetModelVisible(false);
            HealthChanged?.Invoke(Health);
            AudioDirector.Instance?.PlayPlayerHit();

            if (HasAnimatorParameter(hitTrigger, AnimatorControllerParameterType.Trigger))
                animator.SetTrigger(hitTrigger);

            if (Health <= 0)
            {
                IsDead = true;
                SetForwardSpeed(0f);
                if (HasAnimatorParameter(deathTrigger, AnimatorControllerParameterType.Trigger))
                    animator.SetTrigger(deathTrigger);
                Died?.Invoke();
            }
        }

        public void ResetForRun()
        {
            IsDead = false;
            Health = 3;
            Lane = 1;
            verticalVelocity = 0f;
            laneVelocity = 0f;
            slideTimer = 0f;
            attackTimer = 0f;
            invulnerabilityTimer = 0f;
            SetForwardSpeed(12f);
            characterController.enabled = false;
            transform.position = new Vector3(0f, 0f, -3f);
            characterController.enabled = true;
            characterController.height = standingHeight;
            characterController.center = Vector3.up * (standingHeight * 0.5f);
            SetModelVisible(true);
            SetAnimatorBool(slidingParameter, false);
            HealthChanged?.Invoke(Health);
        }

        private void UpdateAnimation()
        {
            if (animator == null)
                return;

            SetAnimatorBool(runningParameter, ForwardSpeed > 0.1f && characterController.isGrounded && slideTimer <= 0f);
            SetAnimatorBool(jumpingParameter, !characterController.isGrounded && slideTimer <= 0f);
            SetAnimatorBool(slidingParameter, slideTimer > 0f);
        }

        private void CacheModelRenderers()
        {
            Renderer[] found = GetComponentsInChildren<Renderer>(true);
            rendererCount = Mathf.Min(found.Length, modelRenderers.Length);
            for (int i = 0; i < rendererCount; i++)
                modelRenderers[i] = found[i];
        }

        private void SetModelVisible(bool visible)
        {
            renderersVisible = visible;
            for (int i = 0; i < rendererCount; i++)
                if (modelRenderers[i] != null)
                    modelRenderers[i].enabled = visible;
        }

        private bool HasAnimatorParameter(string parameterName, AnimatorControllerParameterType type)
        {
            if (animator == null || string.IsNullOrEmpty(parameterName))
                return false;

            foreach (AnimatorControllerParameter parameter in animator.parameters)
                if (parameter.name == parameterName && parameter.type == type)
                    return true;
            return false;
        }

        private void SetAnimatorBool(string parameterName, bool value)
        {
            if (animator == null || string.IsNullOrEmpty(parameterName))
                return;

            foreach (AnimatorControllerParameter parameter in animator.parameters)
            {
                if (parameter.name == parameterName && parameter.type == AnimatorControllerParameterType.Bool)
                {
                    animator.SetBool(parameterName, value);
                    return;
                }
            }
        }

        private void OnDrawGizmosSelected()
        {
            Gizmos.color = Color.red;
            Gizmos.DrawWireSphere(transform.position + Vector3.up + Vector3.back * 1.35f, attackRangeRadius);
        }
    }
}
