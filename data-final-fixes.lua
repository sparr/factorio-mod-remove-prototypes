-- every key of data.raw that contains entities
local entity_types = { ["accumulator"] = true, ["arithmetic-combinator"] = true, ["artillery-flare"] = true, ["artillery-projectile"] = true, ["artillery-turret"] = true, ["artillery-wagon"] = true, ["assembling-machine"] = true, ["beacon"] = true, ["boiler"] = true, ["capsule"] = true, ["car"] = true, ["cargo-wagon"] = true, ["character-corpse"] = true, ["cliff"] = true, ["combat-robot"] = true, ["constant-combinator"] = true, ["construction-robot"] = true, ["container"] = true, ["corpse"] = true, ["decider-combinator"] = true, ["electric-pole"] = true, ["electric-turret"] = true, ["entity-ghost"] = true, ["explosion"] = true, ["fire"] = true, ["fish"] = true, ["flame-thrower-explosion"] = true, ["fluid-turret"] = true, ["fluid-wagon"] = true, ["flying-text"] = true, ["furnace"] = true, ["gate"] = true, ["generator"] = true, ["heat-pipe"] = true, ["inserter"] = true, ["lab"] = true, ["lamp"] = true, ["land-mine"] = true, ["loader"] = true, ["locomotive"] = true, ["logistic-container"] = true, ["logistic-robot"] = true, ["mining-drill"] = true, ["monolith"] = true, ["offshore-pump"] = true, ["pipe-to-ground"] = true, ["pipe"] = true, ["player-port"] = true, ["player"] = true, ["power-switch"] = true, ["programmable-speaker"] = true, ["projectile"] = true, ["pump"] = true, ["radar"] = true, ["rail-chain-signal"] = true, ["rail-remnants"] = true, ["rail-signal"] = true, ["reactor"] = true, ["roboport"] = true, ["rocket-silo"] = true, ["solar-panel"] = true, ["splitter"] = true, ["storage-tank"] = true, ["straight-rail"] = true, ["tile"] = true, ["transport-belt"] = true, ["turret"] = true, ["underground-belt"] = true, ["unit-spawner"] = true, ["unit"] = true, ["wall"] = true, }

-- given a recipe and an item, remove that item from the recipe's ingredients and results
-- remove the recipe if it's left with no results
function remove_recipe_ingredient_or_result(recipe, item_name)
  if recipe.result == item_name then
    remove_one_prototype("recipe", recipe.name)
    return
  end
  if recipe.results then
    for i,result in pairs(recipe.results) do
      if result.name == item_name then
        table.remove(recipe.results, i)
      end
    end
    if #recipe.results == 0 then
      remove_one_prototype("recipe", recipe.name)
      return
    end
  end
  for _,ingredients_table in ipairs({
    recipe.ingredients or {},
    recipe.normal and recipe.normal.ingredients or {},
    recipe.expensive and recipe.expensive.ingredients or {},
    }) do
    for i,ingredient in pairs(ingredients_table) do
      if ingredient[1] == item_name or ingredient.name == item_name then
        table.remove(ingredients_table, i)
      end
    end
  end
end

-- given a technology and a recipe, remove an unlock effect for that recipe if the technology has it
function remove_technology_unlock(tech, recipe_name)
  if tech.effects then
    for i,effect in pairs(tech.effects) do
      if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
        table.remove(tech.effects, i)
      end
    end
  end
end

-- given a prototype type and name, remove that single prototype
function remove_one_prototype(type, name)
  if data.raw[type] then
    log(serpent.line({type,name,data.raw[type][name] and data.raw[type][name].name or ""}))
    if data.raw[type][name] then
      if string.sub(type,1,4) == "item" then -- item or item-with-whatever
        log("x")
        -- eliminate recipe->item dependencies
        for recipe_name,recipe in pairs(data.raw.recipe) do
          remove_recipe_ingredient_or_result(recipe, name)
        end
        -- eliminate achievement->item dependencies
        for _,achievement_type in ipairs({"produce-per-hour-achievement","produce-achievement"}) do
          for achievement_name,achievement in pairs(data.raw[achievement_type]) do
            if achievement.item_product == name then
              data.raw[achievement_type][achievement_name] = nil
            end
          end
        end
        -- eliminate entity->item dependencies
        for entity_type,_ in pairs(entity_types) do
          if data.raw[entity_type] then
            for entity_name,entity in pairs(data.raw[entity_type]) do
              log(serpent.line({entity_type,entity_name,entity.minable}))
              if entity.minable and entity.minable.result == name then
                entity.minable.result = nil
              end
              -- if this item places an entity with a blank order, copy it
              if data.raw[type][name].place_result == entity_name and not entity.order then
                entity.order = data.raw[type][name].order
              end
            end
          end
        end
      end
      -- game won't start if we leave a type with zero prototypes
      -- skip the actual delete, but still do all the prerequisite stuff for effect  
      if table_size(data.raw[type])>1 then
        data.raw[type][name] = nil
      end
      if type == "recipe" then
        -- eliminate technology->recipe dependencies
        for tech_name,tech in pairs(data.raw.technology) do
          remove_technology_unlock(tech, name)
        end
        -- eliminate module->recipe dependencies
        for module_name,module in pairs(data.raw.module) do
          if module.limitation then
            for i,recipe_name in pairs(module.limitation) do
              if recipe_name == name then
                table.remove(module.limitation, i)
              end
            end
          end
        end
      end
      if entity_types[type] then
        -- eliminate entity->item dependencies
        for item_name,item in pairs(data.raw.item) do
          if item.place_result == name then
            item.place_result = nil
          end
        end
      end
      if type == "technology" then
        -- eliminate technology->technology dependencies
        for technology_name,technology in pairs(data.raw.technology) do
          if technology.prerequisites then
            for i,prerequisite in pairs(technology.prerequisites) do
              if prerequisite == name then
                table.remove(technology.prerequisites, i)
              end
            end
          end
        end
        -- eliminate tutorial->technology dependencies
        for tutorial_name,tutorial in pairs(data.raw.tutorial) do
          if tutorial.technology == name then
            remove_one_prototype("tutorial",tutorial_name)
          end
        end
      end
      if type == "trivial-smoke" then
        -- eliminate artillery-projectile->trivial-smoke dependencies
        for ap_name,ap in pairs(data.raw["artillery-projectile"]) do
          if ap.action and ap.action.action_delivery and ap.action.action_delivery.target_effects then
            for i,effect in pairs(ap.action.action_delivery.target_effects) do
              if effect.type == "create-trivial-smoke" and effect.smoke_name == name then
                table.remove(ap.action.action_delivery.target_effects, i)
              end
            end
          end
        end
      end
      if type == "tutorial" then
        -- eliminate tutorial->tutorial dependencies
        for tutorial_name,tutorial in pairs(data.raw.tutorial) do
          if tutorial.dependencies then
            for i,dependency in pairs(tutorial.dependencies) do
              if dependency == name then
                table.remove(tutorial.dependencies, i)
              end
            end
            if #tutorial.dependencies == 0 then
              tutorial.dependencies = nil
            end
          end
        end
      end
      -- TODO remove prototypes that have other hard dependencies on this one
    end
  end
end

-- given a prototype name or type.name, remove every matching prototype
function remove_prototype(name)
  local dot = string.find(name, ".", 1, true) -- plain no-patterns matching
  if dot then
    -- specific type.name
    remove_one_prototype( string.sub(name,1,dot-1) , string.sub(name,dot+1) )
  else
    -- remove this name of every type
    for type,prototypes in pairs(data.raw) do
      remove_one_prototype(type,name)
    end
  end
end

local prototype_list_string = settings.startup['remove-prototypes-prototype-list'].value

log(serpent.line(data.raw.item["artillery-wagon"]))

-- split the list on commas, remove each listed name
for entry in string.gmatch(prototype_list_string, "[^,]+") do
  remove_prototype(entry)
end

