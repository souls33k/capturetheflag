local pending_kills = {}
local trapchest = {}

local TRAP_DAMAGE = 150
local TRAP_KILL_IMAGE = "ctf_kill_list_trapchest.png"


local function is_support_paxel(stack)
	return stack:get_name() == "ctf_mode_classes:support_paxel"
end


local function get_trapchest(pos)
	return trapchest[minetest.hash_node_position(pos)]
end


local function register_trapchest(pos, placer)
	local team = ctf_teams.get(placer)

	trapchest[minetest.hash_node_position(pos)] = {
		player = placer:get_player_name(),
		team = team,
	}
end


local function remove_trapchest(pos)
	trapchest[minetest.hash_node_position(pos)] = nil
	minetest.remove_node(pos)
end


local function disarm_trapchest(pos, player)
	local pname = player:get_player_name()

	remove_trapchest(pos)

	minetest.chat_send_player(pname, "Trap chest disarmed.")
end


local function damage_trap_opener(player, trap)
	local pname = player:get_player_name()

	pending_kills[pname] = {
		trap_player = trap and trap.player or nil,
	}

	local hp_before = player:get_hp()

	minetest.log("warning",
		"[TRAPCHEST DEBUG] victim=" .. pname ..
		" hp_before=" .. hp_before
	)

	player:set_hp(hp_before - TRAP_DAMAGE, {
		type = "set_hp",
		reason = "ctf_trapchest",
	})

	-- set_hp() can be modified by HP-change callbacks.
	-- If the player survived, this trap did not kill them.
	if player:get_hp() > 0 then
		pending_kills[pname] = nil
	end
end


minetest.register_on_dieplayer(function(player)
	local pname = player:get_player_name()
	local kill = pending_kills[pname]

	if not kill then
		return
	end

	pending_kills[pname] = nil

	-- Player-placed enemy trapchests credit the placer.
	-- Map-generated trapchests have no placer, so the killer is blank.
	if ctf_kill_list and ctf_kill_list.add then
		ctf_kill_list.add(
			kill.trap_player or "",
			player,
			TRAP_KILL_IMAGE
		)
	end
end)


minetest.register_on_leaveplayer(function(player)
	pending_kills[player:get_player_name()] = nil
end)


local trap_def = {
	description = "Trap Chest",

	-- Exact closed-chest texture layout.
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

	can_dig = function()
		return false
	end,

	groups = {
		choppy = 2,
		oddly_breakable_by_hand = 2,
	},

	sounds = default.node_sound_wood_defaults(),

	-- Player-placed trap chests remember the placing player's team.
	after_place_node = function(pos, placer)
		register_trapchest(pos, placer)
	end,

	on_rightclick = function(pos, node, clicker, itemstack)
		if not clicker or not clicker:is_player() then
			return itemstack
		end

		local trap = get_trapchest(pos)

		-- Player-placed trapchest:
		-- same-team players cannot trigger or disarm it.
		if trap and trap.team then
			local opener_team = ctf_teams.get(clicker)

			if opener_team == trap.team then
				minetest.chat_send_player(
					clicker:get_player_name(),
					"This is a trap chest."
				)

				return itemstack
			end

			-- Enemy Support Paxel disarms it.
			if is_support_paxel(itemstack) then
				disarm_trapchest(pos, clicker)
				return itemstack
			end

		else
			-- Map-generated trapchest:
			-- it has no owner/team, so any Support Paxel can disarm it.
			if is_support_paxel(itemstack) then
				disarm_trapchest(pos, clicker)
				return itemstack
			end
		end

		-- Enemy player, or anyone opening a neutral/map-generated
		-- trapchest without a Support Paxel: trigger the trap.
		remove_trapchest(pos)
		damage_trap_opener(clicker, trap)

		return itemstack
	end,
}


-- Match the normal default chest's closed-node texture transforms.
trap_def.tiles[6] = trap_def.tiles[5]
trap_def.tiles[5] = trap_def.tiles[3]
trap_def.tiles[3] = trap_def.tiles[3] .. "^[transformFX"


minetest.register_node("ctf_trapchest:trapchest", trap_def)


if ctf_api and ctf_api.register_on_match_end then
	ctf_api.register_on_match_end(function()
		pending_kills = {}
		trapchest = {}
	end)
end
