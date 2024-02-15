-- ascend
-- Ascend by chat command, if possible.
-- By David_G (kestral246@gmail.com)

-- 2024-02-15

-- Use chat command "/ascend" to use.
-- • If can't reach valid destination, will return error message.
-- • If reaches unloaded area, will attempt to load, and request to be rerun.

-- Read configuration settings.
local height = tonumber(minetest.settings:get("ascend_ceiling_height") or 30)
local thickness = tonumber(minetest.settings:get("ascend_ceiling_thickness") or 90)
local ascend_trees = minetest.settings:get_bool("ascend_thru_trees", false)

-- Require "ascend" priviledge to use the /ascend command.
minetest.register_privilege("ascend", {description = "Allow use of /ascend command"})


minetest.register_chatcommand("ascend", {
	params = "",
	description = "Ascend by chat command, if possible.",
	privs = {
		ascend = true
	},
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		local pos = player:get_pos()

		local pos_init_y = math.floor(8*pos.y + 0.5)/8

		-- normal surface = ?.5 +/-, nodes at integer values.
		pos.y = math.floor(pos.y + 0.5)

		local nodename = minetest.get_node(pos).name
		local blocked = false
		local up = 1

		-- Check ground node
		if minetest.get_item_group(nodename, "water") > 0 then
			-- Can't ascend from water.
			minetest.chat_send_player(name, "Can't ascend from water")
			blocked = true

		else
			-- Scan up rest of nodes until reach ceiling or max height.
			while up <= height do
				local newpos = vector.add(pos,{x=0,y=up,z=0})
				local node = minetest.get_node_or_nil(newpos)

				if node ~= nil then
					nodename = node.name
				end

				if node == nil then
					-- Area not loaded.
					local remaining = height + thickness - up
					minetest.load_area(newpos, vector.add(newpos,{x=0,y=remaining,z=0}))
					minetest.chat_send_player(name, "Can't ascend—area not loaded…try again")
					blocked = true
					break

				elseif minetest.registered_nodes[nodename].walkable == true or
						minetest.get_item_group(nodename, "water") > 0 or
						minetest.get_item_group(nodename, "lava") > 0 then
					-- Reached ceiling node. (Ladders can block water and lava.)
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

		elseif up <= height then
			--Reached ceiling. (up pointing to ceiling node)
			local up2 = 0
			local water_surface = false
			local snow_surface = false
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

				if node == nil then
					-- Area not loaded.
					local remaining = height + thickness - (up + up2)
					minetest.load_area(newpos, vector.add(newpos,{x=0,y=remaining,z=0}))
					minetest.chat_send_player(name, "Can't ascend—area not loaded (try again)")
					blocked = true
					break

				elseif minetest.get_item_group(nodename, "water") > 0 then
					--water node
					last_nodename = "water"
					up2 = up2 + 1

				elseif minetest.get_item_group(nodename, "lava") > 0 then
					--lava node
					last_nodename = "lava"
					up2 = up2 + 1

				elseif minetest.get_item_group(nodename, "tree") > 0 or
						minetest.get_item_group(nodename, "leaves") > 0 or
						string.find(nodename, "bush_") ~= nil then
					if ascend_trees == true then
						--tree node normal
						last_node = nodename
						up2 = up2 + 1
					else
						--block on trees or bushes
						minetest.chat_send_player(name, "Can't ascend thru trees or bushes")
						blocked = true
						break
					end

				elseif walkable then
					--normal node
					last_nodename = nodename
					surface_node = node
					up2 = up2 + 1

				elseif nodename == "air" or nodename == "ignore" or
						walkable == false then
					-- First node above ground.
					if last_nodename == "lava" then
						-- Can't land on lava.
						minetest.chat_send_player(name, "Can't ascend onto lava")
						blocked = true
						break
					elseif last_nodename == "water" then
						-- Need to land in water. Water plus this node guarantees room.
						water_surface = true
						break
					elseif last_nodename == "default:snow" then
						-- Snow is short enough to not need second air node.
						snow_surface = true
						break
					else
						-- walkable
						break
					end

				else
					minetest.debug("Ascend: unrecognized node!")
					break
				end
			end --while

			pos.x = math.floor(pos.x + 0.5)
			pos.y = math.floor(8*pos.y + 0.5)/8
			pos.z = math.floor(pos.z + 0.5)

			if up2 > thickness then
				minetest.chat_send_player(name, "Can't ascend—ceiling thickness exceeds "..thickness)
			elseif blocked == true then
				--Chat command happens earlier, do nothing and end. 
			else
				--Current node OK, determine offset based on block type.
				local offset = nil
				local nodename_above = minetest.get_node(vector.add(pos,{x=0,y=up+up2+1,z=0})).name
				if water_surface == true then
					-- water doesn't need second air node above
					offset = -1.5
				elseif snow_surface == true then
					-- fallen snow doesn't need second air node above
					offset = -1.375

				-- need to check for second air node above these.
				elseif nodename_above == "air" or
						minetest.registered_nodes[nodename_above].walkable == false then
					if minetest.get_item_group(surface_node.name, "slab") > 0 and
							surface_node.param2 < 4 then
						-- offset for horizontal slabs
						offset = -1
					else
						-- offset for normal nodes
						offset = -0.5
					end
				else
					-- Only one air-like node above solid surface
					minetest.chat_send_player(name, "Can't ascend—not enough room")
				end

				if offset ~= nil then
					local pos_final = vector.add(pos, {x=0,y=up+up2+offset,z=0})
					player:set_pos(pos_final)
					local pos_final_y = math.floor(8*pos_final.y + 0.5)/8
					minetest.chat_send_player(name, "Ascended "..(pos_final_y-pos_init_y).." nodes")
				end
			end

		else
			-- Didn't reach ceiling.
			minetest.chat_send_player(name, "Can't ascend—ceiling height exceeds "..height)
		end
	end,
})
