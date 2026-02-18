local _, sc = ...;

local missing_strings = {};
local obsolete_strings = {};

local warned_missing_string = false;

local locale_found = sc.L ~= nil;
sc.L = sc.L or {};

local function set_localization_fallback()

    setmetatable(sc.L, {
        __index = function(t, key)
            if type(key) ~= "string" then
                return nil
            end

            if __spellcoda_debug__ and not warned_missing_string then
                warned_missing_string = true;
                print("SpellCoda: Missing localization for at least key:", key)
            end

            return key;
        end
    });
end

local function load_localization()

    if not locale_found or not __sc_p_acc.localization_use then
        sc.L = sc.L or {};
        for k, _ in pairs(sc.localizable_strings) do
            sc.L[k] = k;
        end
        set_localization_fallback();
        return;
    end

    if locale_found then
        for k, _ in pairs(sc.localizable_strings) do
            if not sc.L[k] then
                missing_strings[#missing_strings+1] = k;
            end
        end

        for k, _ in pairs(sc.L) do
            if not sc.localizable_strings[k] then
                obsolete_strings[#obsolete_strings+1] = k;
            end
        end
    end

    sc.localized_strings = sc.L;

    for k, v in pairs(sc.localized_strings) do
        sc.L[k] = v;
    end
    for k, v in pairs(sc.localizable_strings) do
        if not sc.L[k] then
            -- put default where missing
            sc.L[k] = v;
        end
    end

    set_localization_fallback();
end

local function format_locale_dump(list)
    local str = "";
    for _, k in ipairs(list) do
        str = str..string.format("L[\"%s\"]=\"\"\n", k);
    end
    return str;
end

local locale = {};
sc.loc = locale;

---------------------------------------------------------------------------------------------------
locale.missing_strings = missing_strings;
locale.obsolete_strings = obsolete_strings;
locale.load_localization = load_localization;
locale.format_locale_dump = format_locale_dump;
locale.locale_found = locale_found;
