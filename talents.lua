local _, sc                = ...;

local class                 = sc.class;
local config                = sc.config;
local apply_effect          = sc.loadouts.apply_effect;
---------------------------------------------------------------------------------------------------
local talents_export        = {};

local expansion_short = "classic";
local talent_code_prefix = "";
local talent_code_suffix = "";
if sc.utils.client_matches(sc.client_flags.tbc) then
    expansion_short = "tbc";
elseif sc.utils.client_matches(sc.client_flags.forever) then
    expansion_short = "forever";
    talent_code_prefix = "v2";
    talent_code_suffix = "t0";
end

local function wowhead_talent_link(code)
    local lowercase_class = string.lower(class);
    return "https://wowhead.com/"..expansion_short.."/talent-calc/" .. lowercase_class .. "/" .. talent_code_prefix .. code;
end

local function wowhead_talent_code_from_url(link)
    -- forever links append the talent allocation order as one more path segment after the code
    local code = link:match("talent%-calc/[^/]+/([^/]*)") or link:match("[^/]*$");
    if code:sub(1, #talent_code_prefix) == talent_code_prefix then
        code = code:sub(#talent_code_prefix + 1);
    end
    return code;
end

local talent_trees;
local talent_rank;
if sc.talent_ranks then
    talent_trees = sc.talent_order;
    talent_rank = function(tree, talent_index)
        local _, _, _, _, pts = GetTalentInfo(tree, talent_index);
        return pts;
    end;
else
    talent_trees = sc.talent_nodes;
    talent_rank = function(_, node_id)
        local node = C_Traits.GetNodeInfo(C_ClassTalents.GetActiveConfigID(), node_id);
        return node and node.currentRank or 0;
    end;
end

local function wowhead_talent_code()
    local talent_code = "";

    local sub_codes = { "", "", "" };
    for i = 1, 3 do
        -- NOTE: GetNumTalents(i) will return 0 on early calls after logging in,
        --       but works fine after reload
        for _, v in ipairs(talent_trees[i]) do
            sub_codes[i] = sub_codes[i]..tostring(talent_rank(i, v));
        end
        local num_redundant = 0;
        local n = #sub_codes[i];
        for k = 1, n do
            if string.sub(sub_codes[i], n-k+1, n-k+1) == "0" then
                num_redundant = num_redundant + 1;
            else
                break;
            end
        end
        sub_codes[i] = string.sub(sub_codes[i], 1, n-num_redundant);
    end
    if sub_codes[2] == "" and sub_codes[3] == "" then
        talent_code = sub_codes[1];
    elseif sub_codes[2] == "" then
        talent_code = sub_codes[1] .. "--" .. sub_codes[3];
    elseif sub_codes[3] == "" then
        talent_code = sub_codes[1] .. "-" .. sub_codes[2];
    else
        talent_code = sub_codes[1] .. "-" .. sub_codes[2] .. "-" .. sub_codes[3];
    end

    if talent_code == "" then
        return "_";
    end
    return talent_code .. "_" .. talent_code_suffix;
end

local function talent_pts(effects, idx)
    return effects.talent_pts[idx] or 0;
end

local function apply_talents(loadout, effects, wowhead_code, forced, undo)

    local i = 1;
    local tree_index = 1;
    local talent_index = 1;

    while wowhead_code:sub(i, i) ~= "" and wowhead_code:sub(i, i) ~= "_" do
        local next = wowhead_code:sub(i, i);
        local next_num = tonumber(next);
        if next == "-" then
            tree_index = tree_index + 1;
            talent_index = 1;
        elseif next_num then
            local pts = next_num;
            local pts_change;
            if undo then
                pts_change = -pts;
            else
                pts_change = pts;
            end
            local idx = tree_index*100 + talent_index;

            effects.talent_pts[idx] = (effects.talent_pts[idx] or 0) + pts_change;
            if pts > 0 and sc.talent_ranks then
                local effect_id = sc.talent_ranks[idx] and sc.talent_ranks[idx][pts];
                if effect_id then
                    apply_effect(effects,
                                 effect_id,
                                 sc.talent_effects[effect_id],
                                 forced,
                                 1,
                                 undo);
                end
            elseif pts > 0 then
                local node_id = sc.talent_nodes[tree_index] and sc.talent_nodes[tree_index][talent_index];
                local effect_id = node_id and sc.node_id_to_spell_id[node_id];
                if effect_id then
                    apply_effect(effects,
                                 effect_id,
                                 sc.talent_effects[effect_id],
                                 forced,
                                 1,
                                 undo,
                                 nil,
                                 nil,
                                 pts);
                end
            end

            talent_index = talent_index + 1;
        end
        i = i + 1;
    end


    if __spellcoda_test_all_data__ and not forced then
        -- Testing all special passives
        local passives_applied = 0;
        for id, e in pairs(sc.passives) do
            apply_effect(effects, id, e, true, 1, false, true, true);
            passives_applied = passives_applied + 1;
        end

        print(passives_applied, "gen passives applied");

        -- Testing all talents
        local applied = 0;
        if sc.talent_ranks then
            for k, _  in pairs(sc.talent_ranks) do
                effects.talent_pts[k] = #sc.talent_ranks[k];
            end

            for _, v in pairs(sc.talent_ranks) do
                for _, i in pairs(v) do
                    apply_effect(effects, i, sc.talent_effects[i], true, 1, false, true, true);
                    applied = applied + 1;
                end
            end
        else
            local config_id = C_ClassTalents.GetActiveConfigID();
            for tree, nodes in pairs(sc.talent_nodes) do
                for j, node_id in ipairs(nodes) do
                    local max_rank = C_Traits.GetNodeInfo(config_id, node_id).maxRanks;
                    local spell_id = sc.node_id_to_spell_id[node_id];
                    effects.talent_pts[tree*100 + j] = max_rank;
                    for rank = 1, max_rank do
                        apply_effect(effects, spell_id, sc.talent_effects[spell_id], true, 1, false, true, true, rank);
                        applied = applied + 1;
                    end
                end
            end
        end
        print(applied, "gen talents applied");

    end
end

local GetNumSkillLines = C_SkillInfo and C_SkillInfo.GetNumSkillLines or GetNumSkillLines;

local skill_line_name_rank;
if C_SkillInfo then
    skill_line_name_rank = function(i)
        local info = C_SkillInfo.GetSkillLineInfo(i);
        return info and info.name, info and info.rank;
    end;
else
    skill_line_name_rank = function(i)
        local name, _, _, rank = GetSkillLineInfo(i);
        return name, rank;
    end;
end

local function loadout_talents_info(loadout)

    --loadout_front.talents.code = sc.talents.wowhead_talent_code();
    loadout.talents.code = wowhead_talent_code();

    -- weapon skills 
    local success = GetNumSkillLines() ~= 0;
    for i = 1, GetNumSkillLines() do
        local skill_lname, skill = skill_line_name_rank(i);
        local wep_subclass = sc.wpn_skill_lname_to_subclass[skill_lname];
        if wep_subclass then
            loadout.wpn_skills[wep_subclass] = skill;
        end
    end

    -- TODO: never triggers, loadout.talents_code is a typo of loadout.talents.code. Fixing only that would retry
    --       forever, since addon_running_time is compared against an absolute GetTime() based grace time
    if sc.core.addon_running_time < sc.core.login_grace_time and
        loadout.talents_code == "_" and
        UnitLevel("player") >= 10 then
        -- edge case when the talents query won't work shortly after logging in
        success = false;
    end

    return success;
end

---------------------------------------------------------------------------------------------------
talents_export.wowhead_talent_link = wowhead_talent_link
talents_export.wowhead_talent_code_from_url = wowhead_talent_code_from_url;
talents_export.wowhead_talent_code = wowhead_talent_code;
talents_export.loadout_talents_info = loadout_talents_info;
talents_export.talent_pts = talent_pts;
talents_export.apply_talents = apply_talents;

sc.talents = talents_export;
