pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
function _init()
-- runs once at the start
	local m=10
	local n=20

	local probs={
		{tile=1,p=0.05}, -- gold
		{tile=-1,p=0.01}, -- wumpus
		{tile=-2,p=0.20} -- pit
	}
	
	local cumulative=make_cumulative(probs)

	world=make_world(m,n,cumulative)

end

function _update()
-- runs 30 times per second
end

function _draw()
-- runs at 30fps

	cls()
	for i=1,#world do
		for j=1,#world[i] do
			local x = (j-1)*6
			local y = (i-1)*6
			local t = world[i][j].tile
			if t == -1 then
				print("w",x,y,8)
			elseif t == -2 then
				print("p",x,y,2)
			elseif t == 1 then
				print("g",x,y,10)
			elseif world[i][j].stench then
				print("s",x,y,7)
			elseif world[i][j].breeze then
				print("b",x,y,7)
			elseif world[i][j].glitter then
				print("*",x,y,11)
			else
				print(".",x,y,5)
			end
		end
	end

end


function make_world(m, n, probs)
-- makes a new world

	local world={}
	
	-- this bit makes all the tiles
	for i=1,m do
		world[i]={}
		for j=1,n do
			
			world[i][j]={
				tile=0,
				visible=false,
				glitter=false,
				stench=false,
				breeze=false,
				collected_gold=false,
				dead_wumpus=false
			}
			
		end
	end
	
	-- this bit marks the tiles and their adjacents properly
	for i=1,m do
		for j=1,n do
			
			world[i][j].tile=make_tile(probs)
			
			flag_adjacent_tiles(i,j,world)
	
		end
	end
	
	world[1][1].tile=0
	world[1][1].visible=true
	
	return world

end

function make_tile(probs)
-- defines what to put in a tile

	local number=rnd()
	
	for _,entry in ipairs(probs) do
		if number<=entry.cum_prob then
			return entry.tile
		end
	end
		
	return 0 -- if no tile type was chosen then its a safe tile

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

	local tile=world[i][j].tile

	for _,delta in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
		
		local new_i=i+delta[1]
		local new_j=j+delta[2]
		
		if world[new_i] and world[new_i][new_j] then -- checks the tile exists
			
			if tile==1 then
				world[new_i][new_j].glitter=true
			elseif tile==-1 then
				world[new_i][new_j].stench=true
			elseif tile==-2 then
				world[new_i][new_j].breeze=true
			end
				
		end
		
	end

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
