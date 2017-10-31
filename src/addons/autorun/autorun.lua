
_addon.author   = 'Eleven Pies';
_addon.name     = 'AutoRun';
_addon.version  = '2.1.0';

require 'common'

local auto_follow;

local function setAutoRun(value)
    if (value) then
        local entity = AshitaCore:GetDataManager():GetEntity();
        local party = AshitaCore:GetDataManager():GetParty();
        local selfindex = party:GetPartyMemberTargetIndex(0);
        local yaw = entity:GetLocalYaw(selfindex);
        local speed = entity:GetMovementSpeed(selfindex);
        local status = entity:GetStatus(selfindex);
        -- On chocobo, so double speed
        if (status == 5) then
            speed = speed * 2;
        end
        local calc_x = math.cos(yaw) * speed * 0.05 * 0.33333333333333333333333333333333;
        local calc_y = 0;
        local calc_z = 0 - (math.sin(yaw) * speed * 0.05 * 0.33333333333333333333333333333333);
        mem.WriteFloat(auto_follow + 12, calc_x); -- DirectionX
        mem.WriteFloat(auto_follow + 16, calc_y); -- DirectionY
        mem.WriteFloat(auto_follow + 20, calc_z); -- DirectionZ
        mem.WriteULong(auto_follow + 36, 0x4000000); -- FollowID
        mem.WriteUChar(auto_follow + 41, 1); -- AutoRun
    else
        print('Follow cancelled.');
        mem.WriteUChar(auto_follow + 41, 0); -- AutoRun
        mem.WriteULong(auto_follow + 36, 0x4000000); -- FollowID
        mem.WriteFloat(auto_follow + 12, 0); -- DirectionX
        mem.WriteFloat(auto_follow + 16, 0); -- DirectionY
        mem.WriteFloat(auto_follow + 20, 0); -- DirectionZ
    end
end

ashita.register_event('command', function(cmd, nType)
    local args = cmd:GetArgs();

    if (#args > 0 and args[1] == '/autorun')  then
        if (#args > 1)  then
            if (args[2] == 'on')  then
                setAutoRun(true);
                return true;
            elseif (args[2] == 'off')  then
                setAutoRun(false);
                return true;
            elseif (args[2] == 'debug')  then
                local entity = AshitaCore:GetDataManager():GetEntity();
                local party = AshitaCore:GetDataManager():GetParty();
                local selfindex = party:GetPartyMemberTargetIndex(0);
                local speed = entity:GetMovementSpeed(selfindex);
                local speed2 = entity:GetMovementSpeed(selfindex);
                local status = entity:GetStatus(selfindex);
                local chocobo;
                if (status == 5) then
                    chocobo = true;
                    print('chocobo: true');
                else
                    chocobo = false;
                    print('chocobo: false');
                end

                print('speed: ' .. tostring(speed) .. ' speed2: ' .. tostring(speed2) .. ' status: ' .. tostring(status));
            end
        end
    end

    return false;
end);

ashita.register_event('load', function()
    local ptr = mem.FindPatternEx('FFXiMain.dll', '8BCFE8????????8B0D????????E8????????8BE885??750CB9', 0, 0);
    if (ptr == 0) then
        print('[ERROR] Failed to read ptr.');
    else
        auto_follow = mem.ReadULong(ptr + 25);
    end
end );

ashita.register_event('unload', function()
end );
