pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
-- main

-- flag bit positions
-- we basically use a bitwise OR to set a flag to true, a bitwise AND with negation to turn it off and a regular bitwise and to check if the flag is on as opposed to keeping like 72 booleans per tile (because we were running out of memory), now we keep just one int per tile
FLAG_VISIBLE = 1 -- 2**0
FLAG_GLITTER = 2 -- 2**1
FLAG_STENCH = 4 -- 2**2
FLAG_BREEZE = 8 -- 2**3
FLAG_COLLECTED_GOLD = 16 -- 2**4
FLAG_DEAD_WUMPUS = 32 -- 2**5

function _init()
-- runs once at the start
	menu_index=0
	current_menu=0 -- start at main menu
	state=0

	main_menu_items={
		{text="pLAY"},
		{text="oPTIONS"},
		{text="iNSTRUCTIONS"}
	}

	options_menu_items={
		{text="rOWS",value=20},
		{text="cOLUMNS",value=20},
		{text="gOLD SPAWN",value=10},
		{text="wUMPUS SPAWN",value=5},
		{text="pIT SPAWN",value=20}
	}
end

function _update()
-- runs 30 times per second
    if state==2 or state==-1 then -- dead or win
        handle_game_end_input()
    elseif state==1 then -- alive
        handle_alive_input(player,world)
    else -- state==0, in menu
        handle_general_menu_input(current_menu,menu_index)
    end
end

function _draw()
-- runs at 30fps
    if state==2 then -- win
        draw_win(player)
    elseif state==1 then -- alive
        draw_alive(player,world)
    elseif state==0 then -- in main menu
        draw_menu()
    else -- state==-1, dead
        draw_dead(player,world)
    end
end

-->8
-- worldgen

function game_start()
-- gets everything ready for a new game

	m=options_menu_items[1].value
	n=options_menu_items[2].value

	reachable={
		{tile=1,p=options_menu_items[3].value/100}, -- gold
		{tile=-1,p=options_menu_items[4].value/100} -- wumpus
	}
	other={
		{tile=-2,p=options_menu_items[5].value/100} -- pit
	}

    world=make_world(m,n,reachable,other)

	player=make_player(world)

	state=1

end

function make_world(m, n, reachable, other)
-- makes a new world

	local world=make_empty_world(m,n) -- first we make an empty world

	local reachables=place_things(world,reachable)	-- then we place the things the player must be able to reach

	place_things(world,other) -- now we finally place all the stuff that doesnt need to be reachable

	local safe_cells={}
	add(safe_cells,{i=1,j=1})
	
	for _,r in ipairs(reachables) do -- now we carve out paths of safe tiles from each reachable to the safe tiles we know
		best=find_nearest_safe_cell(safe_cells,r.i,r.j)
		new_safe_cells=make_safe_path(world,r.i,r.j,best.i,best.j,other)
		foreach(new_safe_cells, function(cell)
			add(safe_cells, cell)
		end)
	end
	
	for i=1,m do -- now we flag the tiles with whatever they need (stench, breeze, etc)
		for j=1,n do
			flag_adjacent_tiles(i,j,world)
		end
	end
	
	world.wumpus_amount,world.gold_amount=count_wumpuses_and_gold(world)

	return world
	
end

function make_empty_world(m, n)
-- makes an empty map
	
	local world={}
	
	for i=1,m do
		world[i]={}
		for j=1,n do
			world[i][j]={
				tile=nil,
				flags=0 -- all flags off
			}
		end
	end
	
	world[1][1].tile=0
	world[1][1].flags=world[1][1].flags | FLAG_VISIBLE

	world.wumpus_amount=0
	world.gold_amount=0

	return world
	
end

function place_things(world, things)
	-- places things in the world
	
	local m=#world
	local n=#world[1]
	
	local placed_things={}
	
	cumulative=make_cumulative(things)	
	
	for i=1,m do
		for j=1,n do
			if world[i][j].tile==nil then
				tile=decide_tile(cumulative)
				if tile~=nil then
					add(placed_things,{i=i,j=j})
					world[i][j].tile=tile
				end
			end
		end
	end
	
	return placed_things
	
end

function find_nearest_safe_cell(safe_cells, i, j)
-- finds the safe cell nearest to (i, j)

	local best=safe_cells[1]

	for _,cell in ipairs(safe_cells) do
		if ((abs(cell.i-i)+abs(cell.j-j)) < (abs(best.i-i)+abs(best.j-j))) then
			best=cell
		end
	end
	
	return best

end

function make_safe_path(world, s_i, s_j, d_i, d_j, overwritable)
-- builds a path of safe tiles from (s_i, s_j) to (d_i, d_j)
-- imma be honest this one's all chatgpt ive got no idea what happens here

	local i, j = s_i, s_j
	local new_safe = {}

	-- build quick lookup set for overwritable tile types
	local overwritable_tiles = {}
	for _, entry in ipairs(overwritable) do
		overwritable_tiles[entry.tile] = true
	end

	-- loop until we reach the goal (or break on safety)
	local steps = 0
	local max_steps = (#world + #world[1]) * 5

	while (i ~= d_i or j ~= d_j) and steps < max_steps do
		-- mark current tile as safe if appropriate (skip start & goal)
		if not (i == s_i and j == s_j) and not (i == d_i and j == d_j) then
			local t = world[i][j].tile
			if t == nil or t == 0 or overwritable_tiles[t] then
				world[i][j].tile = 0
				add(new_safe, {i = i, j = j})
			end
		end

		-- compute direction toward goal
		local di = d_i - i
		local dj = d_j - j

		-- prefer direction toward goal
		local primary_dir
		if abs(di) > abs(dj) then
			primary_dir = {di > 0 and 1 or -1, 0}
		else
			primary_dir = {0, dj > 0 and 1 or -1}
		end

		-- list of all possible orthogonal moves
		local dirs = {
			{1,0}, {-1,0}, {0,1}, {0,-1}
		}

		-- high randomness: 60% chance to go random, else toward goal
		local dir
		if rnd() < 0.6 then
			dir = dirs[flr(rnd(#dirs)) + 1]
		else
			dir = primary_dir
		end

		-- apply move with bounds clamp
		local ni = mid(1, i + dir[1], #world)
		local nj = mid(1, j + dir[2], #world[1])

		-- if we didnt move (edge hit), pick another random valid move
		if ni == i and nj == j then
			for tries = 1, 4 do
				local alt = dirs[flr(rnd(#dirs)) + 1]
				local ai = mid(1, i + alt[1], #world)
				local aj = mid(1, j + alt[2], #world[1])
				if ai ~= i or aj ~= j then
					ni, nj = ai, aj
					break
				end
			end
		end

		i, j = ni, nj
		steps += 1
	end

	-- optional: a few small extensions beyond the goal for natural look
	local extras = flr(rnd(4)) -- 0..3 extra steps
	for k = 1, extras do
		local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
		local dir = dirs[flr(rnd(#dirs)) + 1]
		local ni = mid(1, i + dir[1], #world)
		local nj = mid(1, j + dir[2], #world[1])

		if not (ni == s_i and nj == s_j) and not (ni == d_i and nj == d_j) then
			local t = world[ni][nj].tile
			if t == nil or t == 0 or overwritable_tiles[t] then
				world[ni][nj].tile = 0
				add(new_safe, {i = ni, j = nj})
			end
		end
	end

	return new_safe
end

function decide_tile(probs)
-- defines what to put in a tile

	local number=rnd()
	
	for _,entry in ipairs(probs) do
		if number<=entry.cum_prob then
			return entry.tile
		end
	end
		
	return nil -- if no tile type was chosen then we skip it

end

function make_cumulative(probs)
-- builds the cumulative probability vector

	local cumulative={}
	local sum=0
	
	for i,entry in ipairs(probs) do
		sum+=entry.p
		add(cumulative,{tile=entry.tile,cum_prob=sum})
	end
	
	return cumulative
	
end

function flag_adjacent_tiles(i, j, world)
-- adds the flags for tiles adjacent to wumpus, pit, gold

	for _,delta in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
		
		local new_i=i+delta[1]
		local new_j=j+delta[2]
		
		if world[new_i] and world[new_i][new_j] and world[new_i][new_j].tile~=nil then -- checks the tile exists and that its not a wall
			
			if world[i][j].tile==1 then
				world[new_i][new_j].flags=world[new_i][new_j].flags | FLAG_GLITTER
			elseif world[i][j].tile==-1 then
				world[new_i][new_j].flags=world[new_i][new_j].flags | FLAG_STENCH
			elseif world[i][j].tile==-2 then
				world[new_i][new_j].flags=world[new_i][new_j].flags | FLAG_BREEZE
			end
				
		end
		
	end

end

function make_player(world)
-- makes a new player character

	local arrows=world.wumpus_amount

	local player={i=1,j=1,facing=3,arrows=arrows,score=0} -- the player starts at spawn, facing down, with the same amount of arrows as wumpuses in the world, with 0 score

	return player

end

function count_wumpuses_and_gold(world)
-- counts the amount of wumpuses and gold spawned in the current world

	local wumpuses=0
	local gold=0
	local m=#world
	local n=#world[1]

	for i=1,m do
		for j=1,n do
			if world[i][j].tile==-1 then -- wumpus on this tile
				wumpuses+=1
            elseif world[i][j].tile==1 then -- gold on this tile
                gold+=1
            end
		end
	end

	return wumpuses,gold

end

-->8
-- gameplay

function handle_game_end_input()
-- handles the player input when they are in-between games, they either won or died
    if btnp(4) then -- player presses Z (play again)
        game_start()
    elseif btnp(5) then -- player presses X (back to menu)
        state=0
    end
end

function handle_alive_input(player, world)
-- handles the player input when they are alive and playing the game

	-- first lets do movement
	move(player,world)

	-- now let's see if the player wants to shoot an arrow
	if btnp(4) then -- the player is pressing the fire key (Z)
		shoot_arrow(player,world)
	end

end

function handle_general_menu_input()
-- handles general menu navigation

	-- this one was a bit optimized by ChatGPT, mainly this part where I get the menu_items
	local menu_items = (current_menu==0 and main_menu_items) or options_menu_items

    if btnp(5) then
        current_menu = 0
        menu_index = 1
        return
    end

    if menu_items then
        if btnp(2) and menu_index>1 then menu_index -= 1 end
        if btnp(3) and menu_index<#menu_items then menu_index += 1 end

        -- call the correct handler once
        if current_menu==0 then
            handle_main_menu_input(menu_items)
        else
            handle_options_menu_input(menu_items)
        end
    end
end

function handle_main_menu_input(menu_items)
	if btnp(4) then -- the player is pressing the "confirm" key (Z)
		if menu_index==1 then -- "Play" is selected
			game_start()
		elseif menu_index==2 then -- "Options" is selected
			current_menu=1
			menu_index=1
		else -- menu_index==3, "Instructions" is selected
			current_menu=2
			menu_index=1
		end
	end
end

function handle_options_menu_input(menu_items)
-- handles the player input when they are in the options menu
	if btn(0) and menu_items[menu_index].value>1 then -- left
		menu_items[menu_index].value-=1
	elseif btn(1) then -- right
		if menu_index>2 then
			local sum=0
			sum+=menu_items[3].value -- gold prob
			sum+=menu_items[4].value -- wumpus prob
			sum+=menu_items[5].value -- pit prob
			if sum<100 then
				menu_items[menu_index].value+=1
			end
		else
			if menu_items[menu_index].value<50 then
				menu_items[menu_index].value+=1
			end
		end
	end
end

function move(player, world)
-- tries to move the player in a certain direction, or makes them look in that direction

	local delta_i,delta_j=0,0

	if btn(5) then -- the player is pressing the turn key (X)
		for dir=0,3 do -- we check the three directions the player could face
			if btnp(dir) then
				player.facing=dir
				break -- we end the loop as soon as we find the direction the player is facing
			end
		end
	else -- the player is not pressing the turn key
		if btnp(0) then -- left
			delta_j=-1
			player.facing=0
		elseif btnp(1) then -- right
			delta_j=1
			player.facing=1
		elseif btnp(2) then -- up
			delta_i=-1
			player.facing=2
		elseif btnp(3) then -- down
			delta_i=1
			player.facing=3
		end
	end

	local new_i=player.i+delta_i
	local new_j=player.j+delta_j

	if new_i~=player.i or new_j~=player.j then

		if world[new_i] and world[new_i][new_j] and world[new_i][new_j].tile~=nil then
			player.i=new_i
			player.j=new_j

			if world[new_i][new_j].tile==1 then -- check for gold in the tile
				collect_gold(player,world,new_i,new_j)
            elseif world[new_i][new_j].tile==-1 or world[new_i][new_j].tile==-2 then -- check for a wumpus or pit in this tile
                lose()
            end

			see_cell(player,world)
		end
	end

end

function see_cell(player, world)
	-- makes the cell the player stepped into visible
	local i=player.i
	local j=player.j

	world[i][j].flags=world[i][j].flags | FLAG_VISIBLE

	for _,delta in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
		local adj_i=i+delta[1]
		local adj_j=j+delta[2]

		if world[adj_i] and world[adj_i][adj_j] and world[adj_i][adj_j].tile==nil then
			world[adj_i][adj_j].flags=world[adj_i][adj_j].flags | FLAG_VISIBLE -- if an adjacent cell is a wall we make it visible as well
		end
	end
end

function shoot_arrow(player, world)
	if player.arrows>0 then
		local dir=player.facing
		local delta_i,delta_j=0,0

		if dir==0 then -- left
			delta_j=-1
		elseif dir==1 then -- right
			delta_j=1
		elseif dir==2 then -- up
			delta_i=-1
		elseif dir==3 then -- down
			delta_i=1
		end

		local target_i=player.i+delta_i
		local target_j=player.j+delta_j

		if world[target_i] and world[target_i][target_j] then

			if world[target_i][target_j].tile~=nil then
				player.arrows-=1

				while world[target_i] and world[target_i][target_j] do

					if world[target_i][target_j].tile==-1 then -- theres a wumpus here
						kill_wumpus(player,world,target_i,target_j)
						break
					elseif world[target_i][target_j].tile==nil then
						break -- we end the loop if we hit a wall
					end

					target_i+=delta_i
					target_j+=delta_j
				end
			end
		end
	end
end

function kill_wumpus(player, world, i, j)
-- kills a wumpus on the target (i, j)
	world[i][j].tile=0 -- now its a safe tile
	world[i][j].flags=world[i][j].flags | FLAG_DEAD_WUMPUS
	world[i][j].flags=world[i][j].flags | FLAG_VISIBLE

	world.wumpus_amount-=1

	for _,delta in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
		local adj_i=i+delta[1]
		local adj_j=j+delta[2]

		if world[adj_i] and world[adj_i][adj_j] then
			world[adj_i][adj_j].flags=world[adj_i][adj_j].flags & ~FLAG_STENCH -- we remove the stench from the adjacent tiles
		end
	end

	player.score+=1000

	if world.wumpus_amount==0 then
	    win()
    end
end

function collect_gold(player, world, i, j)
-- collects a gold bar on the target (i, j)
	world[i][j].tile=0 -- now its a regular safe tile, no gold
	world[i][j].flags=world[i][j].flags | FLAG_COLLECTED_GOLD
	world.gold_amount-=1

	for _,delta in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
		local adj_i=i+delta[1]
		local adj_j=j+delta[2]

		if world[adj_i] and world[adj_i][adj_j] then
			world[adj_i][adj_j].flags=world[adj_i][adj_j].flags & ~FLAG_GLITTER -- we remove the glitter from the adjacent tiles
		end
	end

	player.score+=500

	if world.gold_amount==0 and player.arrows==0 then
	   win()
    end
end

function win()
   state=2 -- game clear state
end

function lose()
    state=-1 -- dead state
end

-->8
-- visuals
-- The visuals display was done with ChatGPT as well as I did not feel like learning how to do the menus right now

function draw_win(player)
-- game clear visuals
end

function draw_alive(player, world)
-- game visuals
	cls()
    local m=#world
    local n=#world[1]

    for i=1,m do
        for j=1,n do
            local cell = world[i][j]
            local c=" "
            local col=7 -- default color

            if cell.flags & FLAG_VISIBLE ~= 0 then
                if player.i==i and player.j==j then
                    c="@"
                    col=8
                elseif cell.tile==nil then
                    c="#"
                    col=5
                elseif cell.tile==1 then
                    c="$"
                    col=10
                elseif cell.tile==-1 then
                    c="w"
                    col=9
                elseif cell.tile==-2 then
                    c="p"
                    col=6
                else
                    c="."
                    col=7
                end

                if player.i~=i or player.j~=j then
                    if cell.flags & FLAG_GLITTER ~= 0 then
                        c="*"
                        col=11
                    elseif cell.flags & FLAG_STENCH ~= 0 then
                        c="^"
                        col=9
                    elseif cell.flags & FLAG_BREEZE ~= 0 then
                        c="~"
                        col=12
                    end
                end
            end

            print(c, j*8, i*8, col)
        end
    end

    print("arrows: "..player.arrows,0,70,7)
    print("score: "..player.score,0,78,7)

end

function draw_menu()
-- chooses which menu to draw
    if current_menu == 0 then -- Main menu
        draw_main_menu()
    elseif current_menu == 1 then -- Options
        draw_options_menu()
    else -- current_menu==2, Instructions
        draw_instructions_menu()
    end
end


function draw_main_menu()
    cls() -- clear screen

    -- title
    local title = "HUNT THE WUMPUS"
    local title_x = 64 - (#title*4) -- 4 pixels per char in Pico-8
    print(title, title_x, 10, 7)

    -- menu items
    local menu_y = 50
    for i, item in ipairs(main_menu_items) do
        local text_x = 64 - (#item.text*4)
        local color = (menu_index == i) and 8 or 7
        print(item.text, text_x, menu_y, color)
        menu_y += 10
	end

end

function draw_options_menu()
    cls() -- clear screen

    for i, item in ipairs(options_menu_items) do
        local y = 16 + (i-1)*8 -- tighter vertical spacing

        -- highlight selected
        if menu_index == i then
            rectfill(0, y-1, 127, y+7, 3) -- highlight background
            print("▶", 2, y, 7)
        end

        -- option name
        print(item.text, 10, y, 7)

        -- slider visuals
        local slider_max = 100
        if i <= 2 then slider_max = 50 end -- first two options are rows/cols

        local value = item.value
        if value > slider_max then value = slider_max end

        local slider_width = 30
        local slider_x = 90

        rect(slider_x, y, slider_x + slider_width, y + 6, 7) -- outline
        rectfill(slider_x, y, slider_x + flr((value/slider_max)*slider_width), y + 6, 8) -- filled slider

        -- print value to the left of slider
        local display_value = tostring(value)
        if i >= 3 then
            display_value = display_value .. "%" -- add % for last 3 sliders
        end
        print(display_value, slider_x - (#display_value*4) - 2, y, 7)
    end

    print("⬅️ ➡️ to adjust, ❎ to go back", 8, 96, 7)
end

function draw_instructions_menu()

end

function draw_dead(player, world)
-- dead player visuals
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
