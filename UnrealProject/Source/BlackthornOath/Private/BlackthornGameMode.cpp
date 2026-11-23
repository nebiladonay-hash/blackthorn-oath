#include "BlackthornGameMode.h"

#include "BlackthornOathCharacter.h"
#include "BlackthornSaveGame.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "Kismet/GameplayStatics.h"

ABlackthornGameMode::ABlackthornGameMode()
{
    PrimaryActorTick.bCanEverTick = true;
}

void ABlackthornGameMode::BeginPlay()
{
    Super::BeginPlay();
    LoadProgress();

    PlayerCharacter = Cast<ABlackthornOathCharacter>(
        UGameplayStatics::GetPlayerCharacter(this, 0));

    if (PlayerCharacter)
    {
        PlayerCharacter->OnPlayerDied.AddDynamic(this, &ABlackthornGameMode::HandlePlayerDeath);
    }
}

void ABlackthornGameMode::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);

    if (RunState != EBlackthornRunState::Running || !IsValid(PlayerCharacter))
    {
        return;
    }

    RunElapsed += DeltaSeconds;
    const float CurrentSpeed = FMath::Min(
        InitialSpeed + RunElapsed * SpeedAcceleration, MaximumSpeed);

    PlayerCharacter->ForwardSpeed = CurrentSpeed;
    Distance = FMath::Max(0.0f,
        FVector::Dist2D(RunStartLocation, PlayerCharacter->GetActorLocation()) / 100.0f);

    OnRunUpdated.Broadcast();
}

void ABlackthornGameMode::BeginRun()
{
    if (!IsValid(PlayerCharacter))
    {
        PlayerCharacter = Cast<ABlackthornOathCharacter>(
            UGameplayStatics::GetPlayerCharacter(this, 0));
    }

    if (!PlayerCharacter)
    {
        UE_LOG(LogTemp, Error, TEXT("Blackthorn Oath: no player character is possessed."));
        return;
    }

    UGameplayStatics::SetGamePaused(this, false);
    PlayerCharacter->ResetForRun();

    Distance = 0.0f;
    Kills = 0;
    RunRelics = 0;
    RunElapsed = 0.0f;
    RunStartLocation = PlayerCharacter->GetActorLocation();
    RunState = EBlackthornRunState::Running;
    OnRunUpdated.Broadcast();
}

void ABlackthornGameMode::PauseRun()
{
    if (RunState != EBlackthornRunState::Running)
    {
        return;
    }

    RunState = EBlackthornRunState::Paused;
    UGameplayStatics::SetGamePaused(this, true);
    OnRunUpdated.Broadcast();
}

void ABlackthornGameMode::ResumeRun()
{
    if (RunState != EBlackthornRunState::Paused)
    {
        return;
    }

    UGameplayStatics::SetGamePaused(this, false);
    RunState = EBlackthornRunState::Running;
    OnRunUpdated.Broadcast();
}

void ABlackthornGameMode::EndRun()
{
    if (RunState != EBlackthornRunState::Running &&
        RunState != EBlackthornRunState::Paused)
    {
        return;
    }

    UGameplayStatics::SetGamePaused(this, false);
    RunState = EBlackthornRunState::GameOver;
    BestDistance = FMath::Max(BestDistance, FMath::FloorToInt(Distance));
    SaveProgress();
    OnRunUpdated.Broadcast();
}

void ABlackthornGameMode::AddKill()
{
    ++Kills;
    OnRunUpdated.Broadcast();
}

void ABlackthornGameMode::AddRelic()
{
    ++RunRelics;
    ++RelicBank;
    SaveProgress();
    OnRunUpdated.Broadcast();
}

void ABlackthornGameMode::SaveProgress()
{
    if (!SaveData)
    {
        SaveData = Cast<UBlackthornSaveGame>(
            UGameplayStatics::CreateSaveGameObject(UBlackthornSaveGame::StaticClass()));
    }

    if (!SaveData)
    {
        return;
    }

    SaveData->BestDistance = BestDistance;
    SaveData->RelicBank = RelicBank;
    UGameplayStatics::SaveGameToSlot(SaveData, SaveSlotName, 0);
}

void ABlackthornGameMode::LoadProgress()
{
    if (UGameplayStatics::DoesSaveGameExist(SaveSlotName, 0))
    {
        SaveData = Cast<UBlackthornSaveGame>(
            UGameplayStatics::LoadGameFromSlot(SaveSlotName, 0));
    }

    if (SaveData)
    {
        BestDistance = SaveData->BestDistance;
        RelicBank = SaveData->RelicBank;
    }
    else
    {
        SaveData = Cast<UBlackthornSaveGame>(
            UGameplayStatics::CreateSaveGameObject(UBlackthornSaveGame::StaticClass()));
    }
}

void ABlackthornGameMode::HandlePlayerDeath()
{
    EndRun();
}
