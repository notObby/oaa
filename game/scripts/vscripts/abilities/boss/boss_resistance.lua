LinkLuaModifier("modifier_boss_resistance", "abilities/boss/boss_resistance.lua", LUA_MODIFIER_MOTION_NONE) --- PERTH VIPPITY PARTIENCE
LinkLuaModifier("modifier_boss_truesight_oaa", "abilities/boss/boss_resistance.lua", LUA_MODIFIER_MOTION_NONE)

boss_resistance = class(AbilityBaseClass)

function boss_resistance:GetIntrinsicModifierName()
  return "modifier_boss_resistance"
end

-----------------------------------------------------------------------------------------

modifier_boss_resistance = class(ModifierBaseClass)

function modifier_boss_resistance:IsHidden()
  return true
end

function modifier_boss_resistance:IsPurgable()
  return false
end

function modifier_boss_resistance:DeclareFunctions()
  return {
    MODIFIER_PROPERTY_TOTAL_CONSTANT_BLOCK,
    MODIFIER_EVENT_ON_TAKEDAMAGE,
    MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
    MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
  }
end

if IsServer() then
  function modifier_boss_resistance:GetModifierTotal_ConstantBlock(keys)
    local parent = self:GetParent()
    local damageReduction = self:GetAbility():GetSpecialValueFor("percent_damage_reduce")

    if keys.attacker == parent then -- boss degen nonsense
      return 0
    end

    local inflictor = keys.inflictor
    if parent:CheckForAccidentalDamage(inflictor) then
      -- Block all damage if it was accidental
      return keys.damage
    end

    return keys.damage * damageReduction / 100
  end

  function modifier_boss_resistance:OnTakeDamage(event)
    local parent = self:GetParent()   -- boss
    local ability = self:GetAbility() -- boss_resistance

    local attacker = event.attacker
    local victim = event.unit
    local inflictor = event.inflictor
    local damage = event.damage

    if not attacker or attacker:IsNull() or not victim or victim:IsNull() then
      return
    end

    -- Check if damaged entity is not this boss
    if victim ~= parent then
      return
    end

    -- Check if it's self damage
    if attacker == victim then
      return
    end

    -- Check if it's accidental damage
    if parent:CheckForAccidentalDamage(inflictor) then
      return
    end

    -- Find what tier is this boss if its defined and set the appropriate damage_threshold
    local tier = parent.BossTier or 1
    local damage_threshold = BOSS_AGRO_FACTOR or 15
    damage_threshold = damage_threshold * tier

    -- Check if damage is less than the threshold
    -- second check is for invis/smoked units with Radiance type damage (damage below the threshold)
    if damage <= damage_threshold and parent:GetHealth() / parent:GetMaxHealth() > 50/100 then
      return
    end

    if not ability or ability:IsNull() then
      return
    end

    local revealDuration = ability:GetSpecialValueFor("reveal_duration")

    -- Reveal the attacker for revealDuration seconds
    attacker:AddNewModifier(parent, ability, "modifier_boss_truesight_oaa", {duration = revealDuration})
  end

  function modifier_boss_resistance:GetModifierPhysicalArmorBonus()
    local parent = self:GetParent()
    if self.checkArmor then
      return 0
    else
      self.checkArmor = true
      local base_armor = parent:GetPhysicalArmorBaseValue()
      local current_armor = parent:GetPhysicalArmorValue(false)
      self.checkArmor = false
      local min_armor = base_armor - 25
      if current_armor < min_armor then
        return min_armor - current_armor
      end
    end
    return 0
  end

  function modifier_boss_resistance:GetModifierIncomingDamage_Percentage(keys)
    local percentDamageSpells = {
      anti_mage_mana_void = true,
      bloodseeker_bloodrage = false,          -- doesn't work on vanilla Roshan
      death_prophet_spirit_siphon = true,     -- doesn't work on vanilla Roshan
      doom_bringer_infernal_blade = true,     -- doesn't work on vanilla Roshan
      huskar_life_break = true,               -- doesn't work on vanilla Roshan
      jakiro_liquid_ice = false,
      necrolyte_reapers_scythe = true,        -- doesn't work on vanilla Roshan
      phantom_assassin_fan_of_knives = false,
      tinker_shrink_ray = true,               -- doesn't work on vanilla Roshan
      winter_wyvern_arctic_burn = true        -- doesn't work on vanilla Roshan
    }

    local damageReduction = self:GetAbility():GetSpecialValueFor("percent_damage_reduce")
    local attacker = keys.attacker
    local inflictor = keys.inflictor

    if not inflictor then
      -- Damage was not done with an ability
      -- Lone Druid Bear Demolish bonus damage
      if attacker:HasModifier("modifier_lone_druid_spirit_bear_demolish") then
        local ability = attacker:FindAbilityByName("lone_druid_spirit_bear_demolish")
        if ability then
          local damage_increase_pct
          if attacker:IsRealHero() then
            damage_increase_pct = ability:GetSpecialValueFor("true_form_bonus_building_damage")
          else
            damage_increase_pct = ability:GetSpecialValueFor("bonus_building_damage")
          end
          if damage_increase_pct and damage_increase_pct > 0 then
            return damage_increase_pct
          end
        end
      end

      -- Tiny Tree Grab bonus damage
      if attacker:HasModifier("modifier_tiny_tree_grab") then
        local ability = attacker:FindAbilityByName("tiny_tree_grab")
        if ability then
          local damage_increase_pct = ability:GetSpecialValueFor("bonus_damage_buildings")
          if damage_increase_pct and damage_increase_pct > 0 then
            return damage_increase_pct
          end
        end
      end

      -- Brewmaster Earth Split Demolish
      if attacker:HasModifier("modifier_brewmaster_earth_pulverize") then
        local ability = attacker:FindAbilityByName("brewmaster_earth_pulverize")
        if ability then
          local damage_increase_pct = ability:GetSpecialValueFor("bonus_building_damage")
          if damage_increase_pct and damage_increase_pct > 0 then
            return damage_increase_pct
          end
        end
      end

      return 0
    end

    -- We will not overcomplicate the interaction with damage amp from Veil:
    -- if parent has Veil debuff, set damage reduction to 100%
    local parent = self:GetParent()
    local hasVeilDebuff = parent:HasModifier("modifier_item_veil_of_discord_debuff")

    local name = inflictor:GetAbilityName()
    if percentDamageSpells[name] then
      if hasVeilDebuff then
        return -100
      else
        return 0 - damageReduction
      end
    end

  --   -- List of modifiers with all damage amplification that need to stack multiplicatively with Boss Resistance
  --   local damageAmpModifiers = {
  --     "modifier_bloodseeker_bloodrage",
  --     "modifier_chen_penitence",
  --     "modifier_shadow_demon_soul_catcher"
  --   }
  --   -- A list matched with the previous one for the AbilitySpecial keys that contain the damage amp values of the modifiers
  --   local ampAbilitySpecialKeys = {
  --     "damage_increase_pct",
  --     "bonus_damage_taken",
  --     "bonus_damage_taken"
  --   }

  --   -- Calculates a value that will counteract damage amplification from the named modifier such that
  --   -- it's as if the damage amplification stacks multiplicatively with Boss Resistance
  --   local function CalculateMultiplicativeAmpStack(modifierName, ampValueKey)
  --     local modifiers = parent:FindAllModifiersByName(modifierName)

  --     local function CalculateAmp(modifier)
  --       if modifier:IsNull() then
  --         return 0
  --       else
  --         local modifierDamageAmp = modifier:GetAbility():GetSpecialValueFor(ampValueKey)
  --         return (100 - damageReduction) / 100 * modifierDamageAmp - modifierDamageAmp
  --       end
  --     end

  --     return sum(map(CalculateAmp, modifiers))
  --   end

  --   local damageAmpReduction = sum(map(CalculateMultiplicativeAmpStack, zip(damageAmpModifiers, ampAbilitySpecialKeys)))
  --   return 0 - damageReduction + damageAmpReduction
    return 0
  end
end

-----------------------------------------------------------------------------------------

modifier_boss_truesight_oaa = class(ModifierBaseClass)

function modifier_boss_truesight_oaa:OnCreated()
  local ability = self:GetAbility()
  if ability and not ability:IsNull() then
    self.maxRevealDist = ability:GetSpecialValueFor("reveal_max_distance")
  else
    self.maxRevealDist = 1500
  end
end

modifier_boss_truesight_oaa.OnRefresh = modifier_boss_truesight_oaa.OnCreated

if IsServer() then
  function modifier_boss_truesight_oaa:CheckState()
    local parent = self:GetParent()
    local caster = self:GetCaster()

    if not caster or caster:IsNull() or parent:HasModifier("modifier_slark_shadow_dance") or parent:HasModifier("modifier_slark_depth_shroud") then
      return {}
    end

    -- Only reveal when within reveal_max_distance of boss
    if (parent:GetAbsOrigin() - caster:GetAbsOrigin()):Length2D() <= self.maxRevealDist then
      return {
        [MODIFIER_STATE_INVISIBLE] = false
      }
    end

    return {}
  end
end

function modifier_boss_truesight_oaa:IsPurgable()
  return false
end

function modifier_boss_truesight_oaa:IsDebuff()
  return true
end

function modifier_boss_truesight_oaa:GetTexture()
  return "item_gem"
end

function modifier_boss_truesight_oaa:IsHidden()
  local parent = self:GetParent()
  local caster = self:GetCaster()

  if not caster or caster:IsNull() or parent:HasModifier("modifier_slark_shadow_dance") or parent:HasModifier("modifier_slark_depth_shroud") then
    return true
  end

  return (parent:GetAbsOrigin() - caster:GetAbsOrigin()):Length2D() > self.maxRevealDist
end

function modifier_boss_truesight_oaa:GetEffectName()
  return "particles/items2_fx/true_sight_debuff.vpcf"
end

function modifier_boss_truesight_oaa:GetEffectAttachType()
  return PATTACH_OVERHEAD_FOLLOW
end

function modifier_boss_truesight_oaa:GetPriority()
  return MODIFIER_PRIORITY_SUPER_ULTRA
end
