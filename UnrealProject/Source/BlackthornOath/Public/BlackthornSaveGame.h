#pragma once

#include "CoreMinimal.h"
#include "GameFramework/SaveGame.h"
#include "BlackthornSaveGame.generated.h"

UCLASS()
class BLACKTHORNOATH_API UBlackthornSaveGame : public USaveGame
{
    GENERATED_BODY()

public:
    UPROPERTY(VisibleAnywhere, BlueprintReadWrite, Category="Progress")
    int32 BestDistance = 0;

    UPROPERTY(VisibleAnywhere, BlueprintReadWrite, Category="Progress")
    int32 RelicBank = 0;
};
