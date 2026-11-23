using UnityEngine;

namespace BlackthornOath
{
    [RequireComponent(typeof(Collider))]
    public sealed class RelicPickup : MonoBehaviour
    {
        [SerializeField] private float bobHeight = 0.12f;
        [SerializeField] private float bobFrequency = 3.85f;
        [SerializeField] private float rotationSpeed = 137.5f;

        private bool collected;
        private Vector3 startPosition;

        private void Awake()
        {
            Collider trigger = GetComponent<Collider>();
            trigger.isTrigger = true;
            startPosition = transform.localPosition;
        }

        private void Update()
        {
            if (collected)
                return;

            transform.Rotate(Vector3.up, rotationSpeed * Time.deltaTime, Space.World);
            Vector3 position = startPosition;
            position.y += Mathf.Sin(Time.time * bobFrequency) * bobHeight;
            transform.localPosition = position;
        }

        private void OnTriggerEnter(Collider other)
        {
            if (collected)
                return;

            RunnerPlayerController player = other.GetComponentInParent<RunnerPlayerController>();
            if (player == null)
                return;

            collected = true;
            RunGameManager.Instance?.AddRelic();
            AudioDirector.Instance?.PlayRelicPickup(transform.position);
            Destroy(gameObject);
        }
    }
}
