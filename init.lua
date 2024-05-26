local S = minetest.get_translator("worldedit_commands")

local worldedit_terraform = {}

mh = worldedit.manip_helpers

local radius_limit = tonumber(minetest.settings:get("worldedit_terraform_radius_limit")) or 10
local threshold_multiplier = tonumber(minetest.settings:get("worldedit_terraform_threshold_multiplier")) or 20
local gauss_sigma = tonumber(minetest.settings:get("worldedit_terraform_gauss_sigma")) or 4
local guass_radius = tonumber(minetest.settings:get("worldedit_terraform_guass_radius")) or 2

if (threshold_multiplier > 100) then
	threshold_multiplier = 100
	minetest.settings:set("worldedit_terraform_threshold_multiplier",100)
end

local function createGaussianKernel(radius, sigma)
    local size = 2 * radius + 1
    local kernel = {}
    local sum = 0
    
    for x = -radius, radius do
        kernel[x + radius + 1] = {}
        for y = -radius, radius do
            kernel[x + radius + 1][y + radius + 1] = {}
            for z = -radius, radius do
                local exponent = -(x*x + y*y + z*z) / (2 * sigma * sigma)
                local value = math.exp(exponent) / (2 * math.pi * sigma * sigma)
                kernel[x + radius + 1][y + radius + 1][z + radius + 1] = value
                sum = sum + value
            end
        end
    end
    
    -- Normalize the kernel
    for x = 1, size do
        for y = 1, size do
            for z = 1, size do
                kernel[x][y][z] = kernel[x][y][z] / sum
            end
        end
    end
    
    return kernel
end

local kernel = createGaussianKernel(guass_radius, gauss_sigma)

worldedit_terraform.terraform = function(pos,radius,threshold,shape)
    
    local manip, area = mh.init_radius(pos, radius+guass_radius)

	local data = mh.get_empty_data(area)

	local min_radius, max_radius = radius * (radius - 1), radius * (radius + 1)
	local offset_x, offset_y, offset_z = pos.x - area.MinEdge.x, pos.y - area.MinEdge.y, pos.z - area.MinEdge.z
	local stride_z, stride_y = area.zstride, area.ystride

    local function convolute(conpos)
        local sum = 0
        for kx = -guass_radius, guass_radius do
            for ky = -guass_radius, guass_radius do
                for kz = -guass_radius, guass_radius do
                    local temppos = vector.new(conpos.x + kx, conpos.y + ky, conpos.z + kz)
                    local node = manip:get_node_at(temppos)
                    if node.name ~= "ignore" then
                        if node.name ~= "air" then
                            sum = sum + kernel[kx + guass_radius + 1][ky + guass_radius + 1][kz + guass_radius + 1]
                        end
                    end
                end
            end
        end
        return sum -- magic number
    end

	for z = -radius, radius do
		-- Offset contributed by z plus 1 to make it 1-indexed
		local new_z = (z + offset_z) * stride_z + 1
		for y = -radius, radius do
			local new_y = new_z + (y + offset_y) * stride_y
			for x = -radius, radius do
				local squared = x * x + y * y + z * z
				if (shape or squared <= max_radius) then
					-- Position is in sphere/cube
                    local manip_index = new_y + (x + offset_x)
                    if (convolute(vector.new(x + pos.x, y+pos.y, z+pos.z)) > threshold) then
                        data[manip_index] = minetest.get_content_id(manip:get_node_at(pos).name)
                    else
                        data[manip_index] = minetest.get_content_id("air")
                    end
				end
			end
		end
	end
    
	mh.finish(manip, data)
end

worldedit_terraform.check_terraform = function(param)
	local found, _, radius, threshold, shape = param:find("^(%d+)%s+(%d+)%s+(%a+)$")
	if found == nil then
		return false
	end
    radius = tonumber(radius)
    threshold = tonumber(threshold)
    if(radius > radius_limit) then radius = radius_limit  end
    if(threshold > 100) then threshold = 100 end
    if(shape == "cube") then shape = true else shape = false end
    threshold = 0.5-(threshold_multiplier/200)+((threshold_multiplier*threshold)/10000)
	return true, radius, threshold, shape
end

worldedit.register_command("terraform", {
	params = "<radius> <threshold offset> <shape>",
	description = S("Terraform the blocks in <shape>(\"cube\" or \"sphere\") at WorldEdit position 1 with radius <radius> and <threshold> [0,100], <radius> is limited to configured max radius."),
	privs = {worldedit=true},
    require_pos = 1,
    parse = worldedit_terraform.check_terraform,
	func = function(name, radius, threshold,shape)
		worldedit_terraform.terraform(worldedit.pos1[name], radius, threshold, shape)
	end,
})