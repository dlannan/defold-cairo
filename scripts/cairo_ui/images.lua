------------------------------------------------------------------------------------------------------------
-- Image related functions
------------------------------------------------------------------------------------------------------------

-- local gles      = require("ffi/OpenGLES2")
-- 
local images = {}

------------------------------------------------------------------------------------------------------------

function images:GetImageData(image)
	local data = cr.cairo_image_surface_get_data(image.image)
	return data
end

------------------------------------------------------------------------------------------------------------

function images:GetConvName(name, filename)
	local cname = string.gsub(filename, "[//\\.]", "_")
	return name.."_"..cname
end

------------------------------------------------------------------------------------------------------------

function images:CreateImageFromFBO( width, height, fboid )

    gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, fboid)
    local pixel_data = ffi.new("uint8_t["..(4*width*height).."]")

    gles.glReadPixels(0, 0, width, height, gles.GL_RGBA, gles.GL_UNSIGNED_BYTE, pixel_data);
    local newImage = self:PNGImage( width, height, pixel_data, 1 )
    gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, 0)
    return newImage
end

------------------------------------------------------------------------------------------------------------

function images:DataImage( width, height, indata, convfname )

    local data = ffi.new( "uint8_t["..( width * height * 4 ).."]" )
    if indata then
        ffi.copy(data, indata, width * height * 4 )
    end

    -- Make a default surface we will render to
    local sf = cr.cairo_image_surface_create_for_data( data, cr.CAIRO_FORMAT_ARGB32, width, height, width * 4 );
    local gen_name = "DataImage"..self.image_counter
    if(convfname) then gen_name = convfname end
    local newImage = { name=gen_name, iname=gen_name, otype=CAIRO_TYPE.IMAGE, filename=nil, image=sf, data=data, width=width, height=height, scalex=1.0, scaley=1.0 }

    if(convfname == nil) then
        self.imageList[gen_name] = newImage 
        self.image_counter = self.image_counter + 1
    end
    return newImage
end

------------------------------------------------------------------------------------------------------------

function images:PNGImage(w, h, data, swap_bgr)

    local newdata = ffi.new("uint8_t["..(w * h * 4).."]")

    local ct = w * h * 4
    for i=0, w * (h-1) * 4, 4 do
        local row = math.floor(i / (w * 4))
        local x = i - row * (w * 4)
        local pos = (w * 4) * (h - row - 1) + x
        if swap_bgr then
            newdata[i] = data[pos+2]
            newdata[i+1] = data[pos+1]
            newdata[i+2] = data[pos]
            newdata[i+3] = 255 --data[pos+3]
        else
           ffi.copy(newdata + i, data + pos, 4)
        end
    end

    local png_image = self:DataImage(w, h, newdata)
    return png_image
end

------------------------------------------------------------------------------------------------------------

function images:BGRImage(image)

    local data = cr.cairo_image_surface_get_data(image.image)
    local newdata = ffi.new("uint8_t["..(image.width * image.height * 4).."]")
print(data, image.height, image.width)

    for i=0, image.width * image.height - 1 do
        newdata[i * 4] = data[i * 4]
        newdata[i * 4+1] = data[i * 4+2]
        newdata[i * 4+2] = data[i * 4+1]
        newdata[i * 4+3] = data[i * 4+3]
    end

    local bgrimage = self:DataImage(image.width, image.height, newdata, image.iname)
    return bgrimage
end

------------------------------------------------------------------------------------------------------------

function images:FlipImage(image, h, v)

    local data = cr.cairo_image_surface_get_data(image.image)
    local newdata = ffi.new("uint8_t["..(image.width * image.height * 4).."]")

    -- Vertical flip
    local ct = 0
    for yloop = image.height-1, 0, -1 do
       ffi.copy(newdata + ct, data+yloop * image.width * 4, image.width * 4)
        ct = ct + image.width * 4
    end
    -- Horizontal flip


    image = self:DataImage(image.width, image.height, newdata)
    return image
end

------------------------------------------------------------------------------------------------------------

function images:DirtyImage(image)

	cr.cairo_surface_flush(image.image)
	cr.cairo_surface_mark_dirty(image.image)
end

------------------------------------------------------------------------------------------------------------

function images:DeleteImage(image)

	if(image.image ~= nil) then
		cr.cairo_surface_finish(image.image)
		cr.cairo_surface_destroy(image.image)
	end
	self.imageList[image.iname] = nil
	image = nil
end

------------------------------------------------------------------------------------------------------------

function images:DeleteAllImages()

	for k,v in pairs(self.imageList) do
		if v ~= nil then self:DeleteImage(v) end
	end
	self.imageList = {}
end

------------------------------------------------------------------------------------------------------------

function images:SaveImage( filename, image)
	
	cr.cairo_surface_write_to_png(image.image, filename)
end

------------------------------------------------------------------------------------------------------------
-- This allows button rendering to be deferred if needed
--  NOTE: Now supports jpg and png internally from imageloader

function images:LoadImage(name, filename, forcenew)

    local convfname = self:GetConvName(name, filename)
    local lookup = self.imageList[convfname]
    if forcenew == nil then
        if lookup ~= nil then 
            return lookup
        end
    end

    local params = {
        --no_async = true,
        channels = 4,
        no_vertical_flip = true,
        --info = true
    } 

    local fh = io.open(filename, "rb")
    if(fh == nil) then 
        print("Cannot load image: ", filename)
        return nil
    end
    
    params.data = fh:read("*a")
    fh:close()   
    params.filename = filename -- Load from file.
    
    local image_resource = imageloader.load(params) -- Load image.
    local datastring = buffer.get_bytes(image_resource.buffer, hash("pixels"))
    local dataarray = ffi.string(datastring, image_resource.header.width * image_resource.header.height * 4)

    local newImage = self:DataImage(image_resource.header.width, image_resource.header.height, ffi.cast("uint8_t *", dataarray), convfname)
    self.imageList[convfname] = newImage
    return newImage 
end

------------------------------------------------------------------------------------------------------------
-- This allows button rendering to be deferred if needed

function images:RenderImage(image, x, y, angle, cb)

    local bigger = 1.0
    local xoff, yoff = 0.0, 0.0
    local hit = false
    if cb then
        -- Increase the scale slightly if the mouse is over the image!!!
        local iobj = { left = x, top = y, width = image.width * image.scalex, height = image.height * image.scaley }
        if InRegion( iobj, Gcairo.oldmx, Gcairo.oldmy ) == true then
            bigger = 1.1
            xoff = -(iobj.width * bigger - (image.width * image.scalex)) * 0.5
            yoff = -(iobj.height * bigger - (image.height * image.scaley)) * 0.5
            hit = true
        end
    end


	cr.cairo_save(self.ctx)
	cr.cairo_translate(self.ctx, x+xoff, y+yoff)

    if angle ~= 0.0 then
        cr.cairo_rotate(self.ctx, angle)
        cr.cairo_translate(self.ctx, -(image.width * image.scalex * 0.5), -(image.height * image.scaley * 0.5))
    end
    cr.cairo_scale(self.ctx, image.scalex * bigger, image.scaley * bigger)

	local c = self.style.image_color
	cr.cairo_set_source_rgba( self.ctx, c.r, c.g, c.b, c.a)

	if c.a ~= 1.0 then
  		cr.cairo_mask_surface(self.ctx, image.image, 0, 0);
  		cr.cairo_fill(self.ctx); 
  	else
		cr.cairo_set_source_surface(self.ctx, image.image, 0, 0);
		cr.cairo_paint (self.ctx);
	end
	
	cr.cairo_restore(self.ctx)
    return hit
end


------------------------------------------------------------------------------------------------------------

function images:ScreenShot( gui, saveimg, nameoverride )

    if gui then self:Render() end
    gSdisp:Flip()

    local stdio = ffi.C
    local W, H = gSdisp.WINwidth, gSdisp.WINheight
    local pixel_data = ffi.new("uint8_t["..(4*W*H).."]")

    gles.glReadPixels(0, 0, W, H, gles.GL_RGBA, gles.GL_UNSIGNED_BYTE, pixel_data);
    -- Image needs flipping and Red and Blue components need swapping
    img = self:PNGImage(W, H, pixel_data, 1)

    -- Save image if needed - png is our preferred format (I think jpg could be done as well)
    if saveimg then
        if gscreenshots == nil then gscreenshots = 1 end
        local name = string.format("cache/screenshots/screenshot%02d.png", gscreenshots)
        if nameoverride then name = nameoverride end
        self:SaveImage(name, img)
        gscreenshots = gscreenshots + 1
    end
    return img
end

------------------------------------------------------------------------------------------------------------

return images

------------------------------------------------------------------------------------------------------------
