local trapchest = {}

local function hash_pos(pos)
	return core.hash_node_position(vector.round(pos))
end

local function get_team(player_name)
	if ctf_teams and ctf_teams.get then
		return ctf_teams.get(player_name)
	end
	return nil
end

local function is_self_trapchest(object_ref, trap)
	if not object_ref:is_player() then
		return nil
	end

	local team = get_team(object_ref:get_player_name())

	if not team or not trap.team then
		return true
	end

	return team == trap.team
end

local function is_medic(player_name)
	if not ctf_classes or not ctf_classes.get then
		return false
	end
	return ctf_classes.get(player_name) == "medic"
end

local function is_paxel(itemstack)
	return itemstack and itemstack:get_name():find("paxel", 1, true) ~= nil
end

local function disarm(pos, player)
	trapchest[hash_pos(pos)] = nil
	core.remove_node(pos)

	local inv = player:get_inventory()
	if inv then
		local stack = ItemStack("ctf_trapchest:trapchest")
		local leftover = inv:add_item("main", stack)
		if not leftover:is_empty() then
			core.add_item(pos, leftover)
		end
	end

	core.chat_send_player(player:get_player_name(), "Trap chest disarmed.")
end

local DAMAGE_RADIUS = 4.5

local function explode(pos, trap)
	trapchest[hash_pos(pos)] = nil
	core.remove_node(pos)

	core.sound_play("tnt_explode", {
		pos = pos,
		gain = 0.8,
		max_hear_distance = 32,
	})

	core.add_particlespawner({
		amount = 20,
		time = 0.1,
		minpos = vector.subtract(pos, 0.5),
		maxpos = vector.add(pos, 0.5),
		minvel = {x = -2, y = -2, z = -2},
		maxvel = {x = 2, y = 2, z = 2},
		minacc = {x = 0, y = -2, z = 0},
		maxacc = {x = 0, y = 0, z = 0},
		minexptime = 0.2,
		maxexptime = 0.6,
		minsize = 2,
		maxsize = 4,
		texture = "tnt_smoke.png",
	})

	for _, object in ipairs(core.get_objects_inside_radius(pos, DAMAGE_RADIUS)) do
		if object:is_player() then
			if not is_self_trapchest(object, trap) then
				local placerobj = trap.placer
					and core.get_player_by_name(trap.placer)

				if placerobj then
					object:punch(placerobj, 1.0, {
						full_punch_interval = 1.0,
						damage_groups = {
							fleshy = 150,
							trapchest = 1,
						},
					}, nil)
				else
					object:set_hp(object:get_hp() - 150)
				end
			end
		end
	end
end

core.register_node("ctf_trapchest:trapchest", {
	description = "Trap Chest",

	paramtype = "light",
	paramtype2 = "facedir",
	legacy_facedir_simple = true,
	is_ground_content = false,

	tiles = {
		{name = "default_chest_top.png", backface_culling = true},
		{name = "default_chest_top.png", backface_culling = true},
		{name = "default_chest_side.png", backface_culling = true},
		{name = "default_chest_side.png", backface_culling = true},
		{name = "default_chest_front.png", backface_culling = true},
	},

	groups = {choppy = 2, oddly_breakable_by_hand = 2},

	selection_box = {
		type = "fixed",
		fixed = {-1/2, -1/2, -1/2, 1/2, 3/16, 1/2},
	},

	drop = "ctf_trapchest:trapchest",

	after_place_node = function(pos, placer)
		local name = placer:get_player_name()

		trapchest[hash_pos(pos)] = {
			placer = name,
			team = get_team(name),
		}
	end,

	on_rightclick = function(pos, node, clicker, itemstack)
		if not clicker or not clicker:is_player() then
			return itemstack
		end

		local trap = trapchest[hash_pos(pos)]

		if not trap then
			core.remove_node(pos)
			return itemstack
		end

		local player_name = clicker:get_player_name()

		if is_paxel(itemstack) and is_medic(player_name) then
			disarm(pos, clicker)
			return itemstack
		end

		if is_self_trapchest(clicker, trap) then
			core.chat_send_player(
				player_name,
				"This is a trap chest!"
			)
			return itemstack
		end

		explode(pos, trap)
		return itemstack
	end,

	can_dig = function(pos, player)
		local trap = trapchests[hash_pos(pos)]

		if not trap then
			return true
		end

		return player and player:is_player()
			and is_self_trapchest(player, trap)
	end,

	on_destruct = function(pos)
		trapchest[hash_pos(pos)] = nil
	end,

	on_blast = function()
		return {}
	end,
})

if ctf_api and ctf_api.register_on_match_end then
	ctf_api.register_on_match_end(function()
		trapchest = {}
	end)
end
