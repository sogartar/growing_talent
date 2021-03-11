::mods_registerMod("growing_talent", 0.1, "growing_talent");

local gt = this.getroottable();

local attributeLevelUpValueNames = [];
attributeLevelUpValueNames.resize(gt.Const.Attributes.COUNT);
attributeLevelUpValueNames[gt.Const.Attributes.Hitpoints] = "hitpointsIncrease";
attributeLevelUpValueNames[gt.Const.Attributes.Bravery] = "braveryIncrease";
attributeLevelUpValueNames[gt.Const.Attributes.Fatigue] = "maxFatigueIncrease";
attributeLevelUpValueNames[gt.Const.Attributes.Initiative] = "initiativeIncrease";
attributeLevelUpValueNames[gt.Const.Attributes.MeleeSkill] = "meleeSkillIncrease";
attributeLevelUpValueNames[gt.Const.Attributes.RangedSkill] = "rangeSkillIncrease";
attributeLevelUpValueNames[gt.Const.Attributes.MeleeDefense] = "meleeDefenseIncrease";
attributeLevelUpValueNames[gt.Const.Attributes.RangedDefense] = "rangeDefenseIncrease";
local attributeNames = [];
attributeNames.resize(gt.Const.Attributes.COUNT + 1);
foreach(key, value in gt.Const.Attributes) {
  attributeNames[value] = key;
}

::mods_queue(null, "mod_hooks(>=20)", function() {
  # Chances are in promiles
  gt.Const.GrowingTalentChance <- 54;
  gt.Const.GrowingTalentPerPointAboveMinChanceBonus <- 9;
  gt.Const.GrowingTalentAttributeLeveledUpChanceMult <- 3;
  gt.Const.GrowingTalentChancePerStartMult <- 0.95;
  gt.Const.GrowingTalentMaxLevel <- this.Const.XP.MaxLevelWithPerkpoints - 1;
  gt.Const.GrowingTalentChancePerLevelUpMult <- 0.94;
  gt.Const.GrowingTalentMaxInitialTalentRolls <- 4;
  gt.Const.GrowingTalentInitialTalentChance <- 333;

  ::mods_hookExactClass("entity/tactical/player", function(o) {
    this.logInfo("entity/tactical/player hook called.");

    local fillAttributeLevelUpValuesOriginal = o.fillAttributeLevelUpValues;
    o.fillAttributeLevelUpValues = function(_amount, _maxOnly = false, _minOnly = false) {
      if (_maxOnly || _minOnly) {
        fillAttributeLevelUpValuesOriginal(_amount, _maxOnly, _minOnly);
      } else {
        fillAttributeLevelUpValuesOriginal(1);
      }
    }

    local getAttributeLevelUpValuesOriginal = o.getAttributeLevelUpValues;
    o.getAttributeLevelUpValues = function() {
      if (this.m.Attributes[0].len() == 0) {
        local minOnly = this.getLevel() - this.getLevelUps() >= this.Const.XP.MaxLevelWithPerkpoints;
        this.fillAttributeLevelUpValues(1, false, minOnly);
      }

      return getAttributeLevelUpValuesOriginal();
    };

    o.growTalents <- function(_v) {
      local currentLevelUp = this.getLevel() - this.getLevelUps();
      if (currentLevelUp >= this.Const.GrowingTalentMaxLevel) {
        return;
      }

      local talents = this.getTalents();
      for (local i = 0; i != this.Const.Attributes.COUNT; i += 1) {
        local done = false;
        while (!done) {
          local growTalentChance;
          if (talents[i] < 3) {
            growTalentChance = this.Const.GrowingTalentChance +
              gt.Const.GrowingTalentPerPointAboveMinChanceBonus * (this.m.Attributes[i][0] - this.Const.AttributesLevelUp[i].Min);
            growTalentChance *= _v[attributeLevelUpValueNames[i]] > 0 ? gt.Const.GrowingTalentAttributeLeveledUpChanceMult : 1;
            growTalentChance = (growTalentChance * this.Math.pow(gt.Const.GrowingTalentChancePerStartMult, talents[i]) *
              this.Math.pow(gt.Const.GrowingTalentChancePerLevelUpMult, currentLevelUp - 1) + 0.5).tointeger();
          } else {
            growTalentChance = 0;
          }
          this.logInfo(attributeNames[i] + " growTalentChance = " + growTalentChance);
          if (this.Math.rand(1, 1000) <= growTalentChance) {
            talents[i] += 1;
            this.logInfo(attributeNames[i] + " talent grown.");
          } else {
            done = true;
          }
        }
      }
    };

    local setAttributeLevelUpValuesOriginal = o.setAttributeLevelUpValues;
    o.setAttributeLevelUpValues = function(_v) {
      this.growTalents(_v);
      setAttributeLevelUpValuesOriginal(_v);
      this.logInfo("player.setAttributeLevelUpValues called.");
    };

    o.fillTalentValues = function() {
      this.logInfo("player.fillTalentValues called.");
      this.addXP(30000);
      this.updateLevel();

      this.m.Talents.resize(this.Const.Attributes.COUNT, 0);

      if (this.getBackground() != null && this.getBackground().isUntalented()) {
        return;
      }

      local talents = this.getTalents();
      for(local roll = 0; roll < gt.Const.GrowingTalentMaxInitialTalentRolls; roll += 1) {
        if (this.Math.rand(1, 1000) <= gt.Const.GrowingTalentInitialTalentChance) {
          local talentAssigned = false;
          while (!talentAssigned) {
            local talent = this.Math.rand(0, this.Const.Attributes.COUNT - 1);
            if (talents[talent] < 3 &&
              (this.getBackground() == null || this.getBackground().getExcludedTalents().find(talent) == null)) {
              talents[talent] += 1;
              talentAssigned = true;
            }
          }
        }
      }
    };
  });
});
