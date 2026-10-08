local pending_kills = {}

local TRAP_DAMAGE = 150
local TRAP_KILL_IMAGE = "ctf_kill_list_trapchest.png"

local function is_support_paxel(stack)
	return stack:get_name() == "ctf_mode_classes:support_paxel"
end

local function disarm_trap(pos, player)
	local pname = player:get_player_name()
	minetest.remove_node(pos)
	minetest.chat_send_player(pname, "Trap chest disarmed.")
end

local function damage_trap_opener(player)
	local pname = player:get_player_name()
	pending_kills[pname] = true

	local hp_before = player:get_hp()
	player:set_hp(hp_before - TRAP_DAMAGE, {
		type = "set_hp",
		reason = "ctf_trapchest",
	})

	-- set_hp() can be modified by HP-change callbacks (for example immunity).
	-- If the player survived, this trap did not kill them and must not appear
	-- in the kill list.
	if player:get_hp() > 0 then
		pending_kills[pname] = nil
	end
end

minetest.register_on_dieplayer(function(player)
	local pname = player:get_player_name()
	if not pending_kills[pname] then
		return
	end

	pending_kills[pname] = nil

	-- There is no enemy player responsible for this death. Its part of the map.
	if ctf_kill_list and ctf_kill_list.add then
		ctf_kill_list.add("", player, TRAP_KILL_IMAGE)
	end
end)

minetest.register_on_leaveplayer(function(player)
	pending_kills[player:get_player_name()] = nil
end)

local trap_def = {
	description = "Trap Chest",

	-- This is the exact closed-chest texture layout produced by
	-- default.chest.register_chest().
	tiles = {
		"default_chest_top.png",
		"default_chest_top.png",
		"default_chest_side.png",
		"default_chest_side.png",
		"default_chest_front.png",
		"default_chest_inside.png",
	},

	paramtype2 = "facedir",
	legacy_facedir_simple = true,
	is_ground_content = false,
	groups = {
		choppy = 2,
		oddly_breakable_by_hand = 2,
	},
	sounds = default.node_sound_wood_defaults(),

on_rightclick = function(pos, node, clicker, itemstack)
	if not clicker or not clicker:is_player() then
		return itemstack
	end

	if is_support_paxel(itemstack) then
		disarm_trap(pos, clicker)
		return itemstack
	end

	minetest.remove_node(pos)
	damage_trap_opener(clicker)
	return itemstack
end,
}

-- default.chest.register_chest() transforms the closed chest's texture
-- indices when it creates the non-mesh closed node. Do the same here so the
-- trap chest is visually indistinguishable from a normal closed chest.
trap_def.tiles[6] = trap_def.tiles[5]
trap_def.tiles[5] = trap_def.tiles[3]
trap_def.tiles[3] = trap_def.tiles[3] .. "^[transformFX"

minetest.register_node("ctf_trapchest:trapchest", trap_def)

if ctf_api and ctf_api.register_on_match_end then
	ctf_api.register_on_match_end(function()
		pending_kills = {}
	end)
end
