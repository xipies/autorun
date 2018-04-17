
_addon.author   = 'Eleven Pies';
_addon.name     = 'AutoRun';
_addon.version  = '3.1.0';

require 'common'

-- Alias for on-top font object must be last alphabetically
local font_alias = '__autorun_addon_zz';
local font_alias_o1 = '__autorun_addon_o1';
local font_alias_o2 = '__autorun_addon_o2';
local font_alias_o3 = '__autorun_addon_o3';
local font_alias_o4 = '__autorun_addon_o4';

local auto_follow;
local last_follow;
local last_follow_cache;
local follow_id_cache;

local default_config = 
{
    font =
    {
        family          = 'Arial',
        size            = 10,
        color           = 0xFFE0E0E0,
        position        = { -180, 44 },
        bold            = true,
        italic          = true,
        outline_enabled = true,
        outline_color   = 0xFF222222,
        outline_size    = 1,
    },
    show = true
};
local autorun_config = default_config;

local function write_float_hack(addr, value)
    local packed = struct.pack('f', value);
    local unpacked = { struct.unpack('B', packed, 1), struct.unpack('B', packed, 2), struct.unpack('B', packed, 3), struct.unpack('B', packed, 4) };

    -- ashita.memory.write_float appears busted in ashita v3, converting to byte array
    ashita.memory.write_array(addr, unpacked);
end

local function setAutoRunEx(value, follow_id)
    if (value) then
        local entity = AshitaCore:GetDataManager():GetEntity();
        local party = AshitaCore:GetDataManager():GetParty();
        local selfindex = party:GetMemberTargetIndex(0);
        local yaw = entity:GetLocalYaw(selfindex);
        local speed = entity:GetSpeed(selfindex);
        local status = entity:GetStatus(selfindex);
        -- On chocobo, so double speed
        if (status == 5) then
            speed = speed * 2;
        end
        local calc_x = math.cos(yaw) * speed * 0.05 * 0.33333333333333333333333333333333;
        local calc_y = 0;
        local calc_z = 0 - (math.sin(yaw) * speed * 0.05 * 0.33333333333333333333333333333333);
        write_float_hack(auto_follow + 12, calc_x); -- DirectionX
        write_float_hack(auto_follow + 16, calc_y); -- DirectionY
        write_float_hack(auto_follow + 20, calc_z); -- DirectionZ
        ashita.memory.write_uint32(auto_follow + 36, follow_id); -- FollowID
        ashita.memory.write_uint8(auto_follow + 41, 1); -- AutoRun
    else
        print('Follow cancelled.');
        ashita.memory.write_uint8(auto_follow + 41, 0); -- AutoRun
        ashita.memory.write_uint32(auto_follow + 36, follow_id); -- FollowID
        write_float_hack(auto_follow + 12, 0); -- DirectionX
        write_float_hack(auto_follow + 16, 0); -- DirectionY
        write_float_hack(auto_follow + 20, 0); -- DirectionZ
    end
end

local function setAutoRun(value)
    setAutoRunEx(value, 0x4000000);
end

local function findEntity(server_id)
    for x = 0, 2303 do
        local entity = GetEntity(x);
        if (entity ~= nil and entity.ServerId == server_id) then
            return entity;
        end
    end

    return nil;
end

local function pauseFollow()
    local follow_id = ashita.memory.read_uint32(auto_follow + 36);
    last_follow = follow_id;
    setAutoRun(false);
end

local function resumeFollow()
    if (last_follow ~= nil and last_follow ~= 0) then
        local entity = findEntity(last_follow);
        -- Should only try to follow if target is nearby
        if (entity ~= nil and entity.WarpPointer ~= 0) then
            setAutoRunEx(true, last_follow);
        end
    end
end

local function clearFollow()
    last_follow = nil;
end

local function createFont(conf, alias, color, x, y)
    -- Create the font object..
    local f = AshitaCore:GetFontManager():Create(alias);
    f:SetColor(color);
    f:SetFontFamily(conf.font.family);
    f:SetFontHeight(conf.font.size);
    f:SetBold(conf.font.bold);
    f:SetItalic(conf.font.italic);
    f:SetPositionX(x);
    f:SetPositionY(y);
    f:SetText('');
    f:SetVisibility(true);
end

local function createFontAll(conf)
    local x = conf.font.position[1];
    local y = conf.font.position[2];
    local w = conf.font.outline_size;

    if (conf.font.outline_enabled) then
        createFont(conf, font_alias_o1, conf.font.outline_color, x - w, y - w);
        createFont(conf, font_alias_o2, conf.font.outline_color, x - w, y + w);
        createFont(conf, font_alias_o3, conf.font.outline_color, x + w, y - w);
        createFont(conf, font_alias_o4, conf.font.outline_color, x + w, y + w);
    end

    createFont(conf, font_alias, conf.font.color, x, y);
end

local function deleteFont(conf, alias)
    -- Delete the font object..
    AshitaCore:GetFontManager():Delete(alias);
end

local function deleteFontAll(conf)
    if (conf.font.outline_enabled) then
        deleteFont(conf, font_alias_o1);
        deleteFont(conf, font_alias_o2);
        deleteFont(conf, font_alias_o3);
        deleteFont(conf, font_alias_o4);
    end

    deleteFont(conf, font_alias);
end

local function setText(conf, alias, text)
    local f = AshitaCore:GetFontManager():Get(alias);
    if (f == nil) then return; end

    f:SetText(text);
end

local function setTextAll(conf, text)
    if (conf.font.outline_enabled) then
        setText(conf, font_alias_o1, text);
        setText(conf, font_alias_o2, text);
        setText(conf, font_alias_o3, text);
        setText(conf, font_alias_o4, text);
    end

    setText(conf, font_alias, text);
end

ashita.register_event('command', function(cmd, nType)
    local args = cmd:args();

    if (#args > 0)  then
        if (args[1] == '/autorun')  then
            if (#args > 1)  then
                if (args[2] == 'on')  then
                    setAutoRun(true);
                    return true;
                elseif (args[2] == 'off')  then
                    setAutoRun(false);
                    return true;
                end
            end
        elseif (args[1] == '/pausefollow' or args[1] == '/pfollow') then
            pauseFollow();
            return true;
        elseif (args[1] == '/resumefollow' or args[1] == '/rfollow')  then
            resumeFollow();

            if (#args > 1) then
                if (args[2] == 'once') then
                    -- One shot, also clear last follow
                    clearFollow();
                end
            end

            return true;
        elseif (args[1] == '/clearfollow')  then
            clearFollow();
            return true;
        end
    end

    return false;
end);

ashita.register_event('load', function()
    local ptr = ashita.memory.findpattern('FFXiMain.dll', 0, '8BCFE8????????8B0D????????E8????????8BE885??750CB9', 0, 0);
    if (ptr == 0) then
        print('[ERROR] Failed to read ptr.');
    else
        auto_follow = ashita.memory.read_uint32(ptr + 25);
    end

    -- Load the configuration file..
    autorun_config = ashita.settings.load_merged(_addon.path .. '/settings/settings.json', autorun_config);

    createFontAll(autorun_config);
end );

ashita.register_event('unload', function()
    -- Get the font object..
    local f = AshitaCore:GetFontManager():Get(font_alias);

    -- Update the configuration position..
    autorun_config.font.position = { f:GetPositionX(), f:GetPositionY() };

    -- Save the configuration file..
    ashita.settings.save(_addon.path .. '/settings/settings.json', autorun_config);

    deleteFontAll(autorun_config);
end );

ashita.register_event('render', function()
    if (autorun_config.show ~= true) then return; end

    -- Detect change
    local follow_id = ashita.memory.read_uint32(auto_follow + 36);
    if (follow_id == follow_id_cache and last_follow == last_follow_cache) then return; end

    -- Ensure we have a valid player..
    local party = AshitaCore:GetDataManager():GetParty();
    if (party:GetMemberActive(0) == false or party:GetMemberServerId(0) == 0) then
        setTextAll(autorun_config, '');
        return;
    end

    local str = '';
    local found = false;
    local entity;

    -- Currently following
    if (found == false and follow_id ~= nil and follow_id ~= 0) then
        entity = findEntity(follow_id);
        if (entity ~= nil) then
            str = entity.Name;
            found = true;
        end
    end

    -- Paused following
    if (found == false and last_follow ~= nil and last_follow ~= 0) then
        entity = findEntity(last_follow);
        if (entity ~= nil) then
            str = '* ' .. entity.Name;
            found = true;
        end
    end

    follow_id_cache = follow_id;
    last_follow_cache = last_follow;

    setTextAll(autorun_config, str);
end);
