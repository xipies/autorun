
_addon.author   = 'Eleven Pies';
_addon.name     = 'AutoRun';
_addon.version  = '3.1.0';

require 'common'

local auto_follow;

local function write_float_hack(addr, value)
    local packed = struct.pack('f', value);
    local unpacked = { struct.unpack('B', packed, 1), struct.unpack('B', packed, 2), struct.unpack('B', packed, 3), struct.unpack('B', packed, 4) };

    -- ashita.memory.write_float appears busted in ashita v3, converting to byte array
    ashita.memory.write_array(addr, unpacked);
end

local function setAutoRun(value)
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
        ashita.memory.write_uint32(auto_follow + 36, 0x4000000); -- FollowID
        ashita.memory.write_uint8(auto_follow + 41, 1); -- AutoRun
    else
        print('Follow cancelled.');
        ashita.memory.write_uint8(auto_follow + 41, 0); -- AutoRun
        ashita.memory.write_uint32(auto_follow + 36, 0x4000000); -- FollowID
        write_float_hack(auto_follow + 12, 0); -- DirectionX
        write_float_hack(auto_follow + 16, 0); -- DirectionY
        write_float_hack(auto_follow + 20, 0); -- DirectionZ
    end
end

ashita.register_event('command', function(cmd, nType)
    local args = cmd:args();

    if (#args > 0 and args[1] == '/autorun')  then
        if (#args > 1)  then
            if (args[2] == 'on')  then
                setAutoRun(true);
                return true;
            elseif (args[2] == 'off')  then
                setAutoRun(false);
                return true;
            end
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
end );

ashita.register_event('unload', function()
end );
