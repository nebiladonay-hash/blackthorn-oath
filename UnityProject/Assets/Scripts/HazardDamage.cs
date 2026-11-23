using UnityEngine;

namespace BlackthornOath
{
    [RequireComponent(typeof(Collider))]
    public sealed class HazardDamage : MonoBehaviour
    {
        private bool alreadyHit;

        private void Reset()
        {
            Collider trigger = GetComponent<Collider>();
            trigger.isTrigger = true;
        }

        private void OnTriggerEnter(Collider other)
        {
            if (alreadyHit)
                return;

            RunnerPlayerController player = other.GetComponentInParent<RunnerPlayerController>();
            if (player == null)
                return;

            alreadyHit = true;
            player.TakeDamage(1);
        }
    }
}
