pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
-- Wumpus World
-- by moofys

-->8
-- main

-- flag bit positions
-- we basically use a bitwise OR to set a flag to true, a bitwise AND with negation to turn it off and a regular bitwise and to check if the flag is on as opposed to keeping like 72 booleans per tile (because we were running out of memory), now we keep just one int per tile
FLAG_VISIBLE = 1 -- 2**0
FLAG_GLITTER = 2 -- 2**1
FLAG_STENCH = 4 -- 2**2
FLAG_BREEZE = 8 -- 2**3
FLAG_VISITED = 16 -- 2**4

-- sprite ids
sprites={
	blank=1,
	wumpus=32,
	player=35,
	facing_left=36,
	facing_right=37,
	facing_up=38,
	facing_down=39,
	stench=5,
	breeze=9,
	glitter=3,
	stench_breeze=13,
	stench_glitter=7,
	breeze_glitter=11,
	stench_breeze_glitter=15,
	pit=34,
	gold=33,
	player_pit=48,
	player_wumpus=49,
	wall=50,
	footprint=17
}

-- menu items
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

function _init()
-- runs once at the start
	menu_index=1
	current_menu=0 -- start at main menu
	state=0
end

function _update()
-- runs 30 times per second
    if state==2 or state==-1 then -- dead or win
        handle_game_end_input(world)
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

	see_cell(player,world)

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

function handle_game_end_input(world)
-- handles the player input when they are in-between games, they either won or died
    if btnp(4) then -- player presses Z (play again)
        game_start()
    elseif btnp(5) then -- player presses X (back to menu)
        state=0
    end

	handle_game_end_camera(world)
end

function handle_game_end_camera(world)
-- camera moves, player stays still
    local m = #world          -- number of rows (height)
    local n = #world[1]       -- number of columns (width)
    -- scroll speed
    local speed = 2
    -- allow camera movement
    if btn(0) then camx -= speed end  -- left
    if btn(1) then camx += speed end  -- right
    if btn(2) then camy -= speed end  -- up
    if btn(3) then camy += speed end  -- down
    -- clamp cam to world bounds (prevents showing beyond walls)
    camx = mid( -8, camx, n*8 - 128 + 8 )  -- n is width (columns)
    camy = mid( -8, camy, m*8 - 128 + 8 )  -- m is height (rows)
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
-- handles the base input for menus
-- this one was a bit optimized by ChatGPT, mainly this part where I get the menu_items
    -- get the appropriate menu items for scrolling and selection
    local menu_items = (current_menu==0 and main_menu_items) or 
                       (current_menu==1 and options_menu_items) or nil

    -- universal back button
    if btnp(5) then
        current_menu = 0
        menu_index = 1
        return
    end

    if current_menu == 2 then
        -- instruction menu scrolling
        handle_instruction_menu_input()
        return
    end

    if menu_items then
        -- up/down navigation
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

-- instruction menu scrolling thingy done by ChatGPT
-- globals for instructions menu
instr_scroll = 0
INSTR_SCROLL_SPEED = 5
INSTR_MAX_Y = 0 -- calculated dynamically after drawing all text

function handle_instruction_menu_input()
    -- scroll instructions up/down
    if btnp(2) then -- up
        instr_scroll = max(instr_scroll - INSTR_SCROLL_SPEED, 0)
    elseif btnp(3) then -- down
        instr_scroll = min(instr_scroll + INSTR_SCROLL_SPEED, INSTR_MAX_Y)
    end

    -- go back to main menu
    if btnp(5) then -- X
        current_menu = 0
        menu_index = 1
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
            elseif world[new_i][new_j].tile==-1 then -- check for a wumpus in this tile
				end_game(world,-1,-1) -- change the games state to "dead" (-1) for the reason "killed by wumpus" (-1)
			elseif world[new_i][new_j].tile==-2 then  -- check for a pit in this tile
				end_game(world,-1,-2) -- change the games state to "dead" (-1) for the reason "fell into a pit" (-2)
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
	world[i][j].flags=world[i][j].flags | FLAG_VISITED

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
	world[i][j].flags=world[i][j].flags | FLAG_VISIBLE

	world.wumpus_amount-=1

	for _,delta in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
		local adj_i=i+delta[1]
		local adj_j=j+delta[2]

		if world[adj_i] and world[adj_i][adj_j] then
			n_wumpus=false
			for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
				local n_i=adj_i+d[1]
				local n_j=adj_j+d[2]

				if world[n_i] and world[n_i][n_j] and world[n_i][n_j].tile==-1 then
					n_wumpus=true
					break
				end
			end
			if not n_wumpus then
				world[adj_i][adj_j].flags=world[adj_i][adj_j].flags & ~FLAG_STENCH -- we remove the stench from the adjacent tiles
			end
		end
	end

	player.score+=1000

	if world.wumpus_amount==0 then
		end_game(world,2,-1) -- Change the game state to "win" (2) for the reason "all wumpuses slain" (-1)
    end
end

function collect_gold(player, world, i, j)
-- collects a gold bar on the target (i, j)
	world[i][j].tile=0 -- now its a regular safe tile, no gold
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
		end_game(world,2,1) -- Change the game state to "win" (2) for the reason "all gold collected" (1)
    end
end

function end_game(world, new_state, reason)
	state=new_state
	game_end_reason=reason
	see_all_tiles(world)
end

function see_all_tiles(world)
	local m=#world
	local n=#world[1]
	for i=1,m do
		for j=1,n do
			world[i][j].flags=world[i][j].flags | FLAG_VISIBLE
		end
	end
end

-->8
-- visuals

camx = 0
camy = 0
function follow_soft(target, cam)
    return cam + (target - cam) * 0.5
end

function draw_alive(player, world)
-- game visuals
	cls()

	local target_camx = (player.j * 8) - 64
	local target_camy = (player.i * 8) - 64

	camx = follow_soft(target_camx, camx)
	camy = follow_soft(target_camy, camy)

	camera(camx, camy)

	
    local m=#world
    local n=#world[1]
	for i=1,m do
		for j=1,n do
			if world[i][j].flags & FLAG_VISIBLE ~=0 then
				draw_tile(player,world,i,j)
			end
		end
	end

	draw_bounds(m,n)

	camera()

    local base_y = 100

	-- BOX 4
	local txt1 = "aRROWS: "..player.arrows
	rectfill(0, base_y, #txt1*4 + 4, base_y+8, 0)
	print(txt1, 2, base_y+2, 7)
	base_y += 10

	-- BOX 5
	local txt2 = "sCORE: "..player.score
	rectfill(0, base_y, #txt2*4 + 8, base_y+8, 0)
	print(txt2, 2, base_y+2, 7)
	base_y += 10

end

function draw_bounds(m,n)
    -- draw walls around the map
    -- m = number of rows (31)
    -- n = number of columns (25)
    
    -- top and bottom walls (span the width, which is n columns)
    for i=-1,n do
        spr(sprites.wall, i*8, -8)           -- top wall
        spr(sprites.wall, i*8, m*8)          -- bottom wall  
    end
    
    -- left and right walls (span the height, which is m rows)
    for j=0,m-1 do
        spr(sprites.wall, -8, j*8)           -- left wall
        spr(sprites.wall, n*8, j*8)          -- right wall
    end
end

function draw_win(player)
-- game clear visuals
	cls()

	camera(camx,camy)

    local m=#world
    local n=#world[1]
	for i=1,m do
		for j=1,n do
			draw_tile(player,world,i,j)
		end
	end

	draw_bounds(m,n)

	camera()

	-- This part with the text boxes was designed with ChatGPT

	-- center X
	local cx = 64

	-- starting Y for first box
	local y = 40

	---------------------------
	-- BOX 1
	local txt1 = "you win!"
	local x1 = cx - (#txt1 * 2)    -- center calculation
	rectfill(x1-2, y-2, x1 + #txt1*4 + 2, y+6, 0)
	print(txt1, x1, y, 7)
	y += 12   -- move down for next box

	if game_end_reason==-1 then
		---------------------------
		-- BOX 2
		local txt2 = "yOU SLAYED EVERY wUMPUS"
		local x2 = cx - (#txt2 * 2)
		rectfill(x2-2, y-2, x2 + #txt2*4 + 2, y+6, 0)
		print(txt2, x2, y, 7)
		y += 12
	else 
		---------------------------
		-- BOX 2
		local txt2 = "yOU COLLECTED ALL GOLD"
		local x2 = cx - (#txt2 * 2)
		rectfill(x2-2, y-2, x2 + #txt2*4 + 2, y+6, 0)
		print(txt2, x2, y, 7)
		y += 12
	end

	---------------------------
	-- BOX 3
	local txt3 = "score: "..player.score
	local x3 = cx - (#txt3 * 2)
	rectfill(x3-2, y-2, x3 + #txt3*4 + 2, y+6, 0)
	print(txt3, x3, y, 7)

    local base_y = 100

	-- BOX 4
	local txt4 = "pRESS Z TO PLAY AGAIN"
	rectfill(0, base_y, #txt4*4 + 4, base_y+8, 0)
	print(txt4, 2, base_y+2, 7)
	base_y += 10

	-- BOX 5
	local txt5 = "pRESS ❎ TO RETURN TO mAIN mENU"
	rectfill(0, base_y, #txt5*4 + 8, base_y+8, 0)
	print(txt5, 2, base_y+2, 7)
	base_y += 10
end

function draw_dead(player, world)
-- dead player visuals
	cls()

	camera(camx,camy)

    local m=#world
    local n=#world[1]
	for i=1,m do
		for j=1,n do
			draw_tile(player,world,i,j)
		end
	end

	draw_bounds(m,n)

	camera()

	-- This part with the text boxes was designed with ChatGPT

	-- center X
	local cx = 64

	-- starting Y for first box
	local y = 40

	---------------------------
	-- BOX 1
	local txt1 = "you died!"
	local x1 = cx - (#txt1 * 2)    -- center calculation
	rectfill(x1-2, y-2, x1 + #txt1*4 + 2, y+6, 0)
	print(txt1, x1, y, 7)
	y += 12   -- move down for next box

	if game_end_reason==-1 then
		---------------------------
		-- BOX 2
		local txt2 = "tHE wUMPUS KILLED YOU"
		local x2 = cx - (#txt2 * 2)
		rectfill(x2-2, y-2, x2 + #txt2*4 + 2, y+6, 0)
		print(txt2, x2, y, 7)
		y += 12
	else 
		---------------------------
		-- BOX 2
		local txt2 = "yOU FELL IN A PIT"
		local x2 = cx - (#txt2 * 2)
		rectfill(x2-2, y-2, x2 + #txt2*4 + 2, y+6, 0)
		print(txt2, x2, y, 7)
		y += 12
	end

	---------------------------
	-- BOX 3
	local txt3 = "score: "..player.score
	local x3 = cx - (#txt3 * 2)
	rectfill(x3-2, y-2, x3 + #txt3*4 + 2, y+6, 0)
	print(txt3, x3, y, 7)

    local base_y = 100

	-- BOX 4
	local txt4 = "pRESS Z TO TRY AGAIN"
	rectfill(0, base_y, #txt4*4 + 4, base_y+8, 0)
	print(txt4, 2, base_y+2, 7)
	base_y += 10

	-- BOX 5
	local txt5 = "pRESS ❎ TO RETURN TO mAIN mENU"
	rectfill(0, base_y, #txt5*4 + 8, base_y+8, 0)
	print(txt5, 2, base_y+2, 7)
	base_y += 10
end

function draw_tile(player, world, i, j)
-- logic for rendering each individual tile

	local player_sprite=sprites.blank
	local facing_sprite=sprites.blank
	local tile_sprite=sprites.blank
	local cell=world[i][j]

	if cell.tile==nil then
		tile_sprite=sprites.wall
	else
		if player.i==i and player.j==j then
			if cell.tile==0 then -- safe tile
				player_sprite=sprites.player
				if player.facing==0 then
					facing_sprite=sprites.facing_left
				elseif player.facing==1 then
					facing_sprite=sprites.facing_right
				elseif player.facing==2 then
					facing_sprite=sprites.facing_up
				else
					facing_sprite=sprites.facing_down
				end
			elseif cell.tile==-1 then -- wumpus here
				player_sprite=sprites.player_wumpus
			elseif cell.tile==-2 then -- pit here
				player_sprite=sprites.player_pit
			end
		end
		if cell.tile==1 then
			tile_sprite=sprites.gold
		elseif cell.tile==-1 then
			tile_sprite=sprites.wumpus
		elseif cell.tile==-2 then
			tile_sprite=sprites.pit
		else
			tile_sprite=cell.flags
		end
	end

	local x = (j - 1) * 8
	local y = (i - 1) * 8

	spr(tile_sprite,   x, y)
	spr(player_sprite, x, y)
	spr(facing_sprite, x, y)

end

-- The visuals display for the menus was done with ChatGPT as well as I did not feel like learning how to do them right now

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
    local title = "wUMPUS wORLD"
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
    cls()

	-- this beauty of a function was fixed by Claude so it can now insert sprites automatically as well as do line breaks properly!
local function print_wrapped(text, x, y, col)
    local max_width = 124  -- 31 chars * 4 pixels per char
    local words = split(text, " ")
    local line = ""
    local line_y = y
    local last_y = y
    local line_x = x
    local line_width = 0  -- track pixel width
    local sprite_on_line = false  -- track if we've drawn a sprite on current line
    
    for w in all(words) do
        local is_sprite = false
        local sprite_id = 0
        local prefix = ""
        local suffix = ""
        
        -- check if word contains {sprite:N}
        local sprite_start = 0
        local sprite_end = 0
        
        for i=1,#w-9 do
            if sub(w, i, i+7) == "{sprite:" then
                sprite_start = i
                -- find closing }
                for j=i+8,#w do
                    if sub(w, j, j) == "}" then
                        sprite_end = j
                        break
                    end
                end
                break
            end
        end
        
        if sprite_start > 0 and sprite_end > 0 then
            prefix = sub(w, 1, sprite_start-1)
            local num_str = sub(w, sprite_start+8, sprite_end-1)
            suffix = sub(w, sprite_end+1, #w)
            sprite_id = tonum(num_str)
            if sprite_id != nil then
                is_sprite = true
            end
        end
        
        if is_sprite then
            -- calculate width needed for prefix
            local prefix_width = #prefix * 4
            if (line != "" or sprite_on_line) and prefix != "" then
                prefix_width += 4  -- space before prefix
            end
            
            -- check if prefix + sprite fits on current line
            if line_width + prefix_width + 8 > max_width and (line != "" or sprite_on_line) then
                -- doesn't fit, print current line and start new one
                if line != "" and line_y - instr_scroll < 96 then
                    print(line, line_x, line_y - instr_scroll, col)
                end
                line = ""
                line_y += 8
                line_x = x
                line_width = 0
                sprite_on_line = false
                prefix_width = #prefix * 4  -- recalc without space
            end
            
            -- add prefix to current line
            if prefix != "" then
                local test_line = (line == "" and not sprite_on_line) and prefix or line.." "..prefix
                line = test_line
                line_width += prefix_width
            end
            
            -- print current line before sprite
            if line != "" and line_y - instr_scroll < 96 then
                print(line, line_x, line_y - instr_scroll, col)
                line_x += line_width
            end
            
            -- draw sprite
            if line_y - instr_scroll < 96 and line_y - instr_scroll >= 0 then
                spr(sprite_id, line_x, line_y - instr_scroll)
            end
            line_x += 8
            line_width += 8
            sprite_on_line = true
            
            -- handle suffix
            line = suffix
            if suffix != "" then
                line_width += #suffix * 4
            end
        else
            local word_width = #w * 4
            local space_width = (line == "" and not sprite_on_line) and 0 or 4
            
            if line_width + space_width + word_width > max_width and (line != "" or sprite_on_line) then
                if line != "" and line_y - instr_scroll < 96 then
                    print(line, line_x, line_y - instr_scroll, col)
                end
                line = w
                line_y += 8
                line_x = x
                line_width = word_width
                sprite_on_line = false
            else
                local test_line = (line == "" and not sprite_on_line) and w or line.." "..w
                line = test_line
                line_width += space_width + word_width
            end
        end
        last_y = line_y
    end
    
    if line != "" and line_y - instr_scroll < 96 then
        print(line, line_x, line_y - instr_scroll, col)
        last_y = line_y + 8
    end
    return last_y
end

    local y = 12

    -- instructions text
    y = print_wrapped("wELCOME TO THE DARK CAVE OF THE wUMPUS, USE THE ARROW KEYS TO MOVE!", 4, y, 7)
    y += 8
    y = print_wrapped("wATCH YOUR STEP! bOTTOMLESS PITS  {sprite:34} PLAGUE THESE CAVERNS. THEIR COLD BREEZE  {sprite:9} INDICATES ADJACENT DANGER.", 4, y, 7)
    y += 8
    y = print_wrapped("bEWARE THE wUMPUS  {sprite:32}! iF YOU ENTER ITS TILE IT WILL DEVOUR YOU! ITS TERRIBLE STENCH  {sprite:5} REVEALS ITS LOCATION NEARBY.", 4, y, 7)
    y += 8
	y = print_wrapped("cHANGE THE DIRECTION YOU ARE FACING BY PRESSING DOWN ❎ AND AN ARROW KEY, THEN SHOOT AT A wUMPUS WITH Z TO KILL IT!", 4, y, 7)
    y += 8
    y = print_wrapped("cOLLECT ALL THE SHINY GOLD  {sprite:33}! iTS GLITTER  {sprite:3} HINTS AT NEARBY TREASURES.", 4, y, 7)
    y += 8
    y = print_wrapped("iF YOU KILL ALL THE wUMPUS (OR COLLECT ALL GOLD IF ARROWS RUN OUT) YOU WIN!", 4, y, 7)
    y += 8
    y = print_wrapped("gOOD LUCK, EXPLORER...", 4, y, 7)
    y += 8

    -- store max scrollable value
    INSTR_MAX_Y = max(0, y - 90)

    -- fill everything at y >= 96 with black
    rectfill(0, 92, 127, 127, 0)

    -- draw back message
    print("❎ to go back, ⬆️⬇️ to sroll", 4, 96, 7)
end

__gfx__
0000000000000000000000000a00000000000000b000bbb000000000b000bbb000000000c000ccc000000000c000ccc000000000c000ccc000000000c000ccc0
000000000000000000000000a7a0000000000000bb0bb0bb00000000bb0bb0bb00000000cc0cc0cc00000000cc0cc0cc00000000cc0cc0cc00000000cc0cc0cc
0000000000000000000000000a000a00000000000bb00000000000000bb00a00000000000cc00000000000000cc00a00000000000cc00000000000000cc00a00
00000000000000000000000000a0a7a000000000000000000000000000a0a7a000000000000000000000000000a0a7a000000000000000000000000000a0a7a0
0000000000000000000000000a7a0a000000000000000000000000000a7a0a000000000000000000000000000a7a0a000000000000000000000000000a7a0a00
00000000000000000000000000a000a000000000b000bbb000000000b0a0bbb000000000c000ccc000000000c0a0ccc000000000b000bbb000000000b0a0bbb0
00000000000000000000000000000a7a00000000bb0bb0bb00000000bb0bb0bb00000000cc0cc0cc00000000cc0cc0cc00000000bb0bb0bb00000000bb0bb0bb
000000000000000000000000000000a0000000000bb00000000000000bb00000000000000cc00000000000000cc00000000000000bb00000000000000bb00000
0000000000000000000000000a00000000000000b000bbb000000000b000bbb000000000c000ccc000000000c000ccc000000000c000ccc000000000c000ccc0
000000000000000000000000a7a0000000000000bb0bb0bb00000000bb0bb0bb00000000cc0cc0cc00000000cc0cc0cc00000000cc0cc0cc00000000cc0cc0cc
0000000000000000000000000a000a00000000000bb00000000000000bb00a00000000000cc00000000000000cc00a00000000000cc00000000000000cc00a00
00000000066006600000000000a0a7a000000000000000000000000000a0a7a000000000000000000000000000a0a7a000000000000000000000000000a0a7a0
0000000006600660000000000a7a0a000000000000000000000000000a7a0a000000000000000000000000000a7a0a000000000000000000000000000a7a0a00
00000000000000000000000000a000a000000000b000bbb000000000b0a0bbb000000000c000ccc000000000c0a0ccc000000000b000bbb000000000b0a0bbb0
00000000000000000000000000000a7a00000000bb0bb0bb00000000bb0bb0bb00000000cc0cc0cc00000000cc0cc0cc00000000bb0bb0bb00000000bb0bb0bb
000000000000000000000000000000a0000000000bb00000000000000bb00000000000000cc00000000000000cc00000000000000bb00000000000000bb00000
09999990000000000055550000000000000000000000000000066000000000000000000000000000000000000000000000000000000000000000000000000000
99799799000000000511115000eeee00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9099990900777700511111150eeeeee0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9097790900aaaa005111111507577570600000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000
90099009077777705111111507777770600000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000
990000990aaaaaa05111111507755770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
09000090777777770511115007777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
90900909aaaaaaaa0055550000700700000000000000000000000000000660000000000000000000000000000000000000000000000000000000000000000000
80dddd0889999998dddddddd00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08eeee809879978900d00d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
de8ee8ed90899809dddddddd00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d758857d909889090d00d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d778877d97788779dddddddd00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d787787d97877879000d00d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0871178008eeee80dddddddd00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
80dddd0880eeee080d00d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000707070707770077070700770000070700770770070007700000000000000000000000000000000000000000000
00000000000000000000000000000000000000707070707770707070707000000070707070707070007070000000000000000000000000000000000000000000
00000000000000000000000000000000000000777070707070777070700070000077707070770070007070000000000000000000000000000000000000000000
00000000000000000000000000000000000000777007707070700007707700000077707700707007707700000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddd0000000000000000000000000000000000000000
0000000000000000000000000000000000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000d00d000000000000000000000000000000000000000000
00000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddd0000000000000000000000000000000000000000
000000000000000000000000000000000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000000000000000000000000000000000000000000
00000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddd0000000000000000000000000000000000000000
00000000000000000000000000000000000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000d00d00000000000000000000000000000000000000000
00000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddd0000000000000000000000000000000000000000
000000000000000000000000000000000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000000000000000000000000000000000000000000
00000000000000000000000000000000dddddddd0000000009999990000000000000000000555500dddddddd0000000000000000000000000000000000000000
0000000000000000000000000000000000d00d0000000000997997990000000000eeee000511115000d00d000000000000000000000000000000000000000000
00000000000000000000000000000000dddddddd0077770090999909000000000eeeeee051111115dddddddd0000000000000000000000000000000000000000
000000000000000000000000000000000d00d00000aaaa00909779090000000007577570511111150d00d0000000000000000000000000000000000000000000
00000000000000000000000000000000dddddddd0777777090099009000000000777777051111115dddddddd0000000000000000000000000000000000000000
00000000000000000000000000000000000d00d00aaaaaa099000099000000000775577051111115000d00d00000000000000000000000000000000000000000
00000000000000000000000000000000dddddddd7777777709000090000000000777777005111150dddddddd0000000000000000000000000000000000000000
000000000000000000000000000000000d00d000aaaaaaaa909009090000000000700700005555000d00d0000000000000000000000000000000000000000000
00000000000000000000000000000000dddddddd0055550000000000000000000000000000000000dddddddd0000000000000000000000000000000000000000
0000000000000000000000000000000000d00d00051111500000000000000000000000000000000000d00d000000000000000000000000000000000000000000
00000000000000000000000000000000dddddddd5111111500000000000000000000000000000000dddddddd0000000000000000000000000000000000000000
000000000000000000000000000000000d00d00051111115000000000000000000000000000000000d00d0000000000000000000000000000000000000000000
00000000000000000000000000000000dddddddd5111111500000000000000000000000000000000dddddddd0000000000000000000000000000000000000000
00000000000000000000000000000000000d00d05111111500000000000000000000000000000000000d00d00000000000000000000000000000000000000000
00000000000000000000000000000000dddddddd0511115000000000000000000000000000000000dddddddd0000000000000000000000000000000000000000
000000000000000000000000000000000d00d00000555500000000000000000000000000000000000d00d0000000000000000000000000000000000000000000
00000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddd0000000000000000000000000000000000000000
0000000000000000000000000000000000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000d00d000000000000000000000000000000000000000000
00000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddd0000000000000000000000000000000000000000
000000000000000000000000000000000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000000000000000000000000000000000000000000
00000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddd0000000000000000000000000000000000000000
00000000000000000000000000000000000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000d00d00000000000000000000000000000000000000000
00000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddd0000000000000000000000000000000000000000
000000000000000000000000000000000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__map__
0000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
