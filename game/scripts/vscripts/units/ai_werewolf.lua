function Spawn( entityKeyValues )
	if not IsServer() then
		return
	end

	if thisEntity == nil then
		return
	end

	thisEntity.HowlAbility = thisEntity:FindAbilityByName("werewolf_howl")
	thisEntity:SetContextThink( "WerewolfThink", WerewolfThink, 1 )
end

function WerewolfThink()
  if not IsValidEntity(thisEntity) or not thisEntity:IsAlive() or thisEntity:IsDominated() then
		return -1
  end

	if GameRules:IsGamePaused() then
		return 1
  end

  if not thisEntity.bInitialized then
		thisEntity.vInitialSpawnPos = thisEntity:GetOrigin()
    thisEntity.bInitialized = true
  end

  local fDistanceToOrigin = ( thisEntity:GetOrigin() - thisEntity.vInitialSpawnPos ):Length2D()

  if fDistanceToOrigin > 2000 then
    if fDistanceToOrigin > 10 then
      return RetreatHome()
    end
    return 1
  end

	if thisEntity.HowlAbility and thisEntity.HowlAbility:IsFullyCastable() then
    local ability = thisEntity.HowlAbility
    local radius = ability:GetSpecialValueFor("radius")
    local friendlies = FindUnitsInRadius(
      thisEntity:GetTeamNumber(),
      thisEntity:GetAbsOrigin(),
      nil,
      radius,
      DOTA_UNIT_TARGET_TEAM_FRIENDLY,
      DOTA_UNIT_TARGET_ALL,
      DOTA_UNIT_TARGET_FLAG_NONE,
      FIND_ANY_ORDER,
      false
    )
    if #friendlies > 1 then
      return Howl()
    end
	end

	return 0.5
end


function Howl()
	ExecuteOrderFromTable({
		UnitIndex = thisEntity:entindex(),
		OrderType = DOTA_UNIT_ORDER_CAST_NO_TARGET,
		AbilityIndex = thisEntity.HowlAbility:entindex(),
	})
	return 1
end

function RetreatHome()
	ExecuteOrderFromTable({
		UnitIndex = thisEntity:entindex(),
		OrderType = DOTA_UNIT_ORDER_MOVE_TO_POSITION,
		Position = thisEntity.vInitialSpawnPos
  })
  return 2
end

