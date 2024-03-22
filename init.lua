-- ascend
-- Ascend by chat command, if possible.
-- By David_G (kestral246@gmail.com)

-- 2024-03-20

-- Now supports Minetest Game and MineClone2.

-- Use chat command "/ascend" to use.
-- • If can't reach valid destination, will return error message.
-- • If reaches unloaded area, will attempt to load, and request to be rerun.

-- Read configuration settings.
local height = tonumber(minetest.settings:get("ascend_ceiling_height") or 30)
local thickness = tonumber(minetest.settings:get("ascend_ceiling_thickness") or 90)
local ascend_trees = minetest.settings:get_bool("ascend_thru_trees", false)

-- Require "ascend" priviledge to use the /ascend command.
minetest.register_privilege("ascend", {description = "Allow use of /ascend command"})

-- Fraction display table
local ftable = { "+","⅛","¼–","¼","¼+","⅜","½–",
		"½","½+","⅝","¾–","¾","¾+","⅞","–" }


minetest.register_chatcommand("ascend", {
	params = "",
	description = "Ascend by chat command, if possible.",
	privs = {
		ascend = true
	},
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		local pos = player:get_pos()

		local pos_init_y = math.floor(16*pos.y + 0.5)/16

		-- normal surface = ?.5 +/-, nodes at integer values.
		pos.y = math.floor(pos.y + 0.5)

		local nodename = minetest.get_node(pos).name
		local blocked = false
		local up = 1

		-- Check if player attached to entity.
		if player:get_attach() ~= nil then
			minetest.chat_send_player(name, "Can't ascend while attached to an object")
			blocked = true

		-- Check ground node for water.
		elseif minetest.get_item_group(nodename, "water") > 0 then
			minetest.chat_send_player(name, "Can't ascend from water")
			blocked = true

		--Check ground node for lava.
		elseif minetest.get_item_group(nodename, "lava") > 0 then
			minetest.chat_send_player(name, "Can't ascend from lava")
			blocked = true

		else
			-- Scan up rest of nodes until reach ceiling or max height.
			while up <= height do
				local newpos = vector.add(pos,{x=0,y=up,z=0})
				local node = minetest.get_node_or_nil(newpos)

				if node ~= nil then
					nodename = node.name
				end

				-- Area not loaded.
				if node == nil then
					local remaining = height + thickness - up
					minetest.load_area(newpos, vector.add(newpos,{x=0,y=remaining,z=0}))
					minetest.chat_send_player(name, "Can't ascend—area not loaded…try again")
					blocked = true
					break

				-- Reached ceiling node. (Ladders can block water and lava.)
				elseif minetest.registered_nodes[nodename].walkable == true or
						minetest.get_item_group(nodename, "water") > 0 or
						minetest.get_item_group(nodename, "lava") > 0 then
					-- up remains pointing to ceiling node.
					break

				else
					-- non-walkable, air-like node, keep scanning
					up = up + 1
				end
			end
		end

		if blocked == true then
			--Chat command happens earlier, do nothing and end.

		--Reached ceiling. (up pointing to ceiling node)
		elseif up <= height then
			local up2 = 0
			local water_surface = false
			local snow_height = nil
			local last_nodename = nil
			local surface_node = nil

			--Start scanning through thickness.
			while up2 <= thickness do
				local newpos = vector.add(pos,{x=0,y=up+up2,z=0})
				local node = minetest.get_node_or_nil(newpos)
				local walkable = nil
				if node ~= nil then
					nodename = node.name
					walkable = minetest.registered_nodes[nodename].walkable
				end

				-- Area not loaded. Now also force mapgen if needed.
				if node == nil or nodename == "ignore" then
					local remaining = height + thickness - (up + up2)
					minetest.emerge_area(newpos, vector.add(newpos,{x=0,y=remaining,z=0}))
					minetest.chat_send_player(name, "Can't ascend—area not loaded (try again)")
					blocked = true
					break

				-- Water node.
				elseif (minetest.get_item_group(nodename, "water") > 0 and walkable == false) then
					last_nodename = "water"
					up2 = up2 + 1

				-- Lava node.
				elseif minetest.get_item_group(nodename, "lava") > 0 then
					last_nodename = "lava"
					up2 = up2 + 1

				-- Optionally block on trees and large plants, huge mushrooms, and nodes found in trees.
				elseif minetest.get_item_group(nodename, "tree") > 0 or
						minetest.get_item_group(nodename, "leaves") > 0 or
						(string.find(nodename, "mcl_mangrove:") and string.find(nodename, "roots")) or
						(string.find(nodename, "bush") ~= nil and walkable == true) or
						(string.find(nodename, "cactus") ~= nil and walkable == true) or
						minetest.get_item_group(nodename, "huge_mushroom") > 0 or
						nodename == "mcl_bamboo:bamboo" or
						nodename == "mcl_bamboo:bamboo_1" or
						nodename == "mcl_bamboo:bamboo_2" or
						nodename == "mcl_bamboo:bamboo_3" or
						minetest.get_item_group(nodename, "bee_nest") > 0 or
						minetest.get_item_group(nodename, "cocoa") > 0 then
					if ascend_trees == true then
						--tree node normal
						last_node = nodename
						up2 = up2 + 1
					else
						minetest.chat_send_player(name, "Can't ascend thru trees or other large vegetation")
						blocked = true
						break
					end

				-- Block on doors, walls, fences, panes, and a few more nodes.
				elseif minetest.get_item_group(nodename, "door") > 0 or
						minetest.get_item_group(nodename, "trapdoor") > 0 or
						minetest.get_item_group(nodename, "wall") > 0 or
						minetest.get_item_group(nodename, "fence") > 0 or
						minetest.get_item_group(nodename, "fence_gate") > 0 or
						minetest.get_item_group(nodename, "pane") > 0 or
						string.find(nodename, "mcl_lightning_rods:rod") ~= nil or
						string.find(nodename, "default:mese_post_light") ~= nil then
					minetest.chat_send_player(name, "Can't ascend thru doors, walls, or fences")
					blocked = true
					break

				-- Block on a bunch of miscellaneous nodes.
				elseif minetest.get_item_group(nodename, "anvil") > 0 or
						minetest.get_item_group(nodename, "bed") > 0 or
						minetest.get_item_group(nodename, "cake") > 0 or
						minetest.get_item_group(nodename, "campfire") > 0 or
						minetest.get_item_group(nodename, "cauldron") > 0 or
						minetest.get_item_group(nodename, "flower_pot") > 0 or
						minetest.get_item_group(nodename, "head") > 0 or
						minetest.get_item_group(nodename, "lantern") > 0 or
						minetest.get_item_group(nodename, "map") > 0 or
						nodename == "mcl_bells:bell" or
						string.find(nodename, "mcl_brewing:stand") ~= nil or
						string.find(nodename, "mcl_comparators:comparator") ~= nil or
						string.find(nodename, "mcl_composters:composter") ~= nil or
						nodename == "mcl_enchanting:table" or
						nodename == "mcl_grindstone:grindstone" or
						string.find(nodename, "mcl_hoppers:hopper") ~= nil or
						nodename == "mcl_lanterns:chain" or
						nodename == "mcl_lectern:lectern" then
					minetest.chat_send_player(name, "Can't ascend thru oddly-shaped objects")
					blocked = true
					break

				-- Block if nodes are burning, but treat magma more like lava.
				elseif (minetest.get_item_group(nodename, "fire") > 0 and nodename ~= "mcl_nether:magma") or
						minetest.get_item_group(nodename, "lit_campfire") > 0 or
						nodename == "tnt:tnt_burning" then
					minetest.chat_send_player(name, "Can't ascend thru fire")
					blocked = true
					break

				-- Block on bedrock.
				elseif (nodename == "mcl_core:bedrock") then
					minetest.chat_send_player(name, "Can't ascend thru bedrock")
					blocked = true
					break

				-- All the rest of the normal, walkable nodes.
				elseif walkable then
					last_nodename = nodename
					surface_node = node
					up2 = up2 + 1

				-- Found the first node above ground, only non-walkable nodes are left.
				else
					-- Examine surface node for special processing.
					if last_nodename == "lava" then
						-- Can't land on lava.
						minetest.chat_send_player(name, "Can't ascend onto lava")
						blocked = true
						break
					elseif last_nodename == "water" then
						-- Need to land in water. Water plus this node guarantees room.
						water_surface = true
						break
					elseif last_nodename == "mcl_nether:magma" then
						local two_above = minetest.get_node(vector.add(pos,{x=0,y=up+up2+1,z=0})).name
						if two_above == "air" or
								minetest.registered_nodes[two_above].walkable == false then
							--magma needs two air nodes, otherwise report not enough room.
							minetest.chat_send_player(name, "Can't ascend onto magma")
							blocked = true
						end
						break
					elseif last_nodename == "default:snow" then
						-- Default snow is short enough to not need second air node.
						snow_height = 0.125
						break
					elseif minetest.get_item_group(last_nodename, "top_snow") > 0 then
						--MineClone2 top snow stack (1 to 8 layers)
						local top_snow = minetest.get_item_group(last_nodename, "top_snow")
						if top_snow == 1 then
							snow_height = 0  --short enough
						else
						--Stacked snow (2 = 0.25, ..., 8 = 1.00)
							snow_height = top_snow / 8  --needs second air node
						end
						break
					else
						-- Normal walkable node.
						break
					end
				end
			end --while

			pos.x = math.floor(pos.x + 0.5)
			pos.y = math.floor(16*pos.y + 0.5)/16
			pos.z = math.floor(pos.z + 0.5)

			-- Ceiling too thick.
			if up2 > thickness then
				minetest.chat_send_player(name, "Can't ascend—ceiling thickness exceeds "..thickness)

			-- Ascent was previously blocked.
			elseif blocked == true then
				--Chat command happens earlier, do nothing and end.

			--Current node OK, determine offset and required clearance based on block type.
			else
				local offset = nil
				local nodename_above = minetest.get_node(vector.add(pos,{x=0,y=up+up2+1,z=0})).name
				if water_surface == true then
					-- water doesn't need second air node above
					offset = -1.5

				elseif snow_height ~= nil and snow_height < 0.1875 then  -- either 0.00 or 0.125
					-- snow layer short enough, doesn't need second air node above
					offset = -1.5 + snow_height

				-- Need to check for second air node above these.
				elseif nodename_above == "air" or
						minetest.registered_nodes[nodename_above].walkable == false then
					if minetest.get_item_group(surface_node.name, "slab") > 0 and
							surface_node.param2 < 4 and  --lower horizontal position, default
							string.find(surface_node.name, "_double") == nil and  --mcl
							string.find(surface_node.name, "_top") == nil then  --mcl
						--offset for horizontal slabs
						offset = -1
					elseif snow_height ~= nil then  -- from 0.25 to 1.00
						--mcl top snow stacks (_2+) need second air node above
						offset = -1.5 + snow_height
					elseif surface_node.name == "mcl_flowers:waterlily" or
							minetest.get_item_group(surface_node.name, "carpet") > 0 then
						--waterlily and carpet height = 1/16
						offset = -1.4375
					elseif surface_node.name == "mcl_chests:chest_small" then
						offset = -0.625
						--mcl chest height = 7/8, default chest is a full node
					else
						-- offset for normal nodes
						offset = -0.5
					end

				-- Only one air-like node above solid surface
				else
					minetest.chat_send_player(name, "Can't ascend—not enough room")
				end

				-- Ascent valid.
				if offset ~= nil then
					-- Move player up, applying offset.
					local pos_final = vector.add(pos, {x=0,y=up+up2+offset,z=0})
					player:set_pos(pos_final)

					-- Calculate and display distance traveled, including fractional nodes.
					local pos_final_y = math.floor(16*pos_final.y + 0.5)/16
					local height = pos_final_y - pos_init_y
					local iheight = math.floor(height)
					local frac = (height - iheight) * 16
					if frac == 0 then
						minetest.chat_send_player(name, "Ascended "..iheight.." nodes")
					elseif frac == 15 then
						minetest.chat_send_player(name, "Ascended "..(iheight+1)..ftable[frac].." nodes")
					else
						minetest.chat_send_player(name, "Ascended "..iheight..ftable[frac].." nodes")
					end
				end
			end

		-- Couldn't reach ceiling.
		else
			minetest.chat_send_player(name, "Can't ascend—ceiling height exceeds "..height)
		end
	end,
})
