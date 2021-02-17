------------------------------------------------------------------------------------------------------------
-- Cairo UI - Develop by David Lannan
--
-- Design Notes:
-- The aim of the UI is to provide pixel consistancy for scalable graphics. What this means is the art
-- and the scalable graphics use a common measurement system (currently 1024 x1024) and it auto pixel 
-- scales the output to match the target UI resolution. 
--
-- Why this is needed - Quite often when you scale Cairo you will get pixel blends and stretching that 
-- deform the output. Small fonts are a good example. If you rotate or place some cairo operation on a small 
-- font with a small base scale then you will lose pixels in the operation and the output will look poor.
-- By using a high internal level of scale but maintaining the output to match the target it means 
-- the blending will look good for the target resolution no matter the size.
--
-- When the resolution has a unique aspect (non square) then we adjust the underlying maximum sizes so that
-- it still matches. For example, 640x480 will have a underlying Cairo UI size of 1024x768 rather than 1024x1024
-- to ensure close pixel approximation. A mobile phone type resolution of 480x800 will map to 614x1024
--
-- Cairo UI cannot solve all layout UI problems, but it should make development much easier in the long run.
-- 
------------------------------------------------------------------------------------------------------------

local random = math.random

-- This is somewhat dangerous and could cause name clashes!! should rethink this.
ffi 	= package.preload.ffi()
cr 		= require( "ffi/cairo" )
tween 	= require( "scripts/utils/tween" )

require("scripts/cairo_ui/constants")
require("scripts/utils/geometry")
require("scripts/utils/text")

-- require("framework/byt3dShader")
-- require("framework/byt3dTexture")

------------------------------------------------------------------------------------------------------------
-- Some manager lists -- bit crap.. for the moment

local cairo_ui = {}

------------------------------------------------------------------------------------------------------------

local function AddLibrary( lib, fname ) 
	local res = sys.load_resource(fname)
	print("Loaded: ", fname)
	local tlib = assert(loadstring(res))()
	for k,v in pairs(tlib) do
		lib[k] = v
	end
end
		
------------------------------------------------------------------------------------------------------------

function CAIRO_CHK(ctx)
	local error = cr.cairo_status(ctx)
	if error ~= 0 then
		print( 'cairo error: ', error )
	end
end

------------------------------------------------------------------------------------------------------------
-- The files below are able to use the local namespace to work correctly with cairo_ui

AddLibrary(cairo_ui, "/scripts/cairo_ui/operations.lua")
AddLibrary(cairo_ui, "/scripts/cairo_ui/text.lua")
AddLibrary(cairo_ui, "/scripts/cairo_ui/images.lua")
AddLibrary(cairo_ui, "/scripts/cairo_ui/import_svg.lua")
AddLibrary(cairo_ui, "/scripts/cairo_ui/widgets.lua")
AddLibrary(cairo_ui, "/scripts/cairo_ui/widget_handlers.lua")

------------------------------------------------------------------------------------------------------------

cairo_ui.ibuffer 		= ffi.new( "unsigned short[6]", 1, 0, 2, 3, 2, 0 )
cairo_ui.vertexArray 	= ffi.new( "float[12]", -1.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0,-1.0, 0.0, -1.0,-1.0, 0.0 )
cairo_ui.texCoordArray 	= ffi.new( "float[8]", 0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0 )

------------------------------------------------------------------------------------------------------------
-- Style settings.. change these to change the style of buttons etc
cairo_ui.style = {}
cairo_ui.style.corner_size	= 0.0
cairo_ui.style.border_width = 1.0
cairo_ui.style.button_color			= CAIRO_STYLE.METRO.LBLUE		-- { r=0.8, g=0.5, b=0.5, a=1 }
cairo_ui.style.button_border_color	= CAIRO_STYLE.METRO.LBLUE		-- { r=0.3, g=0, b=0, a=1 }
cairo_ui.style.image_color			= CAIRO_STYLE.WHITE
cairo_ui.style.font_name			= "Century Gothic"

------------------------------------------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------------
-- This list is checked for mouseover, mousedown, mouseup and mousemove type events
-- List is ordered based on declaration order. If you need a button to the front, then delete it and add it again.
cairo_ui.objectList		= {}

------------------------------------------------------------------------------------------------------------
-- Simple cache for images - recommend preloading!!
cairo_ui.imageList		= {}

------------------------------------------------------------------------------------------------------------
cairo_ui.WIDTH			= CAIRO_RENDER.DEFAULT_WIDTH
cairo_ui.HEIGHT 		= CAIRO_RENDER.DEFAULT_HEIGHT
cairo_ui.V_WIDTH		= CAIRO_RENDER.MAX_PIXEL_SIZE
cairo_ui.V_HEIGHT 		= CAIRO_RENDER.MAX_PIXEL_SIZE
cairo_ui.data 			= nil
cairo_ui.tests 			= { "pdf", "svg", "png" }

------------------------------------------------------------------------------------------------------------
-- Cairo Surface, Context and GL Texture Id
cairo_ui.sf 			= nil
cairo_ui.ctx 			= nil
cairo_ui.texId 			= nil

-- OpenGLES Shader used to render Cairo
cairo_ui.uiShader 		= nil
-- OpenGLES Shader parameters
cairo_ui.loc_position 	= nil
cairo_ui.loc_texture  	= nil
cairo_ui.loc_tex0     	= nil

cairo_ui.image_counter	= 1
------------------------------------------------------------------------------------------------------------

cairo_ui.lastMouseButton = {}
cairo_ui.oldmx			 = 0	-- old mouse x
cairo_ui.oldmy			 = 0	-- old mouse y
cairo_ui.currentCursor	 = nil

------------------------------------------------------------------------------------------------------------
cairo_ui.timeLast 		= os.clock()
cairo_ui.written 		= 0

------------------------------------------------------------------------------------------------------------
-- Object Control methods

-- Add a new object to the object list - this is created per frame
-- TODO: Add cahcing mechanisms and so on.

function cairo_ui:AddObject( obj, otype, cb, meta )

	-- new object which wraps the notmal widget
	local nobj = { id=self.objectCount, name=obj.name, otype=otype, callback=cb, cobject=obj, meta=meta  }
	
	-- Some objects have default callback setups (buttons mainly - where we can set objects as buttons)
--	if callback ~= nil then
--		nobj.callback = self:ButtonSetHandler(nobj)
--	end
	self.objectList[tonumber(nobj.id)] = nobj
	self.objectCount = self.objectCount + 1
end

------------------------------------------------------------------------------------------------------------

function cairo_ui:Reset()

	local test = false
	if self.data ~= nil then test = true end
	
	self.slideOutStates	= {}
	self.exploderStates	= {}
	self.listStates		= {}
	self.multiImageStates = {}
	self.cursorStates	= {}
		
	------------------------------------------------------------------------------------------------------------
	-- This list is checked for mouseover, mousedown, mouseup and mousemove type events
	-- List is ordered based on declaration order. If you need a button to the front, then delete it and add it again.
	self.objectList		    = {}
	
	------------------------------------------------------------------------------------------------------------
	-- Simple cache for images - recommend preloading!!
	self.imageList			= {}
	
	------------------------------------------------------------------------------------------------------------
	self.WIDTH			    = CAIRO_RENDER.DEFAULT_WIDTH
	self.HEIGHT 		    = CAIRO_RENDER.DEFAULT_HEIGHT
	self.V_WIDTH		    = CAIRO_RENDER.MAX_PIXEL_SIZE
	self.V_HEIGHT 		    = CAIRO_RENDER.MAX_PIXEL_SIZE
	self.data 			    = nil
	self.tests 			    = { "pdf", "svg", "png" }
	
	------------------------------------------------------------------------------------------------------------
	-- Cairo Surface, Context and GL Texture Id
	self.sf 			    = nil
	self.ctx 			    = nil
	
	-- OpenGLES Shader parameters
	-- self.loc_position 	    = nil
	-- self.loc_texture  	    = nil
	-- self.loc_tex0     	    = nil
	-- 
	self.image_counter	    = 1
	------------------------------------------------------------------------------------------------------------
	
	self.lastMouseButton    = {}
	self.oldmx			    = 0	-- old mouse x
	self.oldmy			    = 0	-- old mouse y
	
	------------------------------------------------------------------------------------------------------------
	self.timeLast 		    = os.clock()
	self.written 		    = 0
	
	self.file_FileSelect 	= ""
	self.file_LastSelect	= ""
	self.file_NewFolder 	= nil

	-- This can be modified per project - defines root level project directory.
	self.currdir 			= nil
	self.dirlist			= nil
	self.select_file		= -1

    self.svgs               = {}
	self.frame				= 0	
	self.fps 				= 0.0
	self.lastclock			= 0.0
end 

------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------
-- Initialise some Cairo informaiton
function cairo_ui:Init(width, height)
	
	self:Reset()
	self.WIDTH 		= width
	self.HEIGHT 	= height
	print(width, height)
	local aspect = height / width
	local calcWidth, calcHeight = CAIRO_RENDER:GetSize(width, aspect)
	self.V_WIDTH 	= calcWidth
	self.V_HEIGHT 	= calcHeight
	
	print("Virtual Screen Size: ", self.V_WIDTH, self.V_HEIGHT)	
	self.data = ffi.new( "uint8_t[?]", self.V_WIDTH * self.V_HEIGHT * 4 )

	-- Make a default surface we will render to
	self.sf = cr.cairo_image_surface_create_for_data( self.data, cr.CAIRO_FORMAT_ARGB32, self.V_WIDTH, self.V_HEIGHT, self.V_WIDTH*4 );
    self.device = cr.cairo_surface_get_device(self.sf)
	self.ctx = cr.cairo_create( self.sf ); CAIRO_CHK(self.ctx)
	
	-- Use an available font - need to work out how to use local file based fonts or convert to scaled fonts.
	cr.cairo_select_font_face( self.ctx, self.style.font_name, cr.CAIRO_FONT_SLANT_NORMAL, 0 ); CAIRO_CHK(self.ctx)

-- 	-- Load and build the shader for cairo
-- 	-- self.uiShader = MakeShader( colour_shader, gui_shader )
-- 	self.uiShader = byt3dShader:NewProgram( colour_shader, gui_shader )
-- 	self.uiShader.name = "Shader_CairoGui"
-- 
--     self.mesh = byt3dMesh:New()
--     self.mesh:SetShader(self.uiShader)
--     self.mesh:SetTexture(self.tex)
--     self.mesh.alpha = 1.0
-- 
--     -- Find the shader parameters we will use
-- 	self.loc_position = self.uiShader.vertexArray
-- 	self.loc_texture  = self.uiShader.texCoordArray[0]
-- 
-- 	self.loc_res      = self.uiShader.loc_res
-- 	self.loc_time     = self.uiShader.loc_time

	self.scaleX = self.V_WIDTH / self.WIDTH 
	self.scaleY = self.V_HEIGHT / self.HEIGHT
	cr.cairo_scale(self.ctx, self.scaleX, self.scaleY)

	-- Builtin images for use with widgets
	self.img_select = self:LoadImage("icon_tick", "data/icons/generic_obj_tick_64.png")
	self.img_folder	= self:LoadImage("icon_folder", "data/icons/generic_obj_folder_64.png")
	self.img_folder.scalex = 0.35
	self.img_folder.scaley = 0.35
	
	if(self.img_arrowup == nil) then 
		self.img_arrowup = self:LoadImage("arrowup", "data/icons/generic_arrowup_64.png") 
		self.img_arrowup.scalex = 16 / self.img_arrowup.width
		self.img_arrowup.scaley = 16 / self.img_arrowup.height
	end
	if(self.img_arrowdn == nil) then 
		self.img_arrowdn = self:LoadImage("arrowdn", "data/icons/generic_arrowdn_64.png") 
		self.img_arrowdn.scalex = 16 / self.img_arrowdn.width
		self.img_arrowdn.scaley = 16 / self.img_arrowdn.height
	end

	self.dwidth = tonumber(sys.get_config("display.width", "800"))
	self.dheight = tonumber(sys.get_config("display.height", "600"))
		
	self.mouseScaleX = (self.WIDTH / self.dwidth )
	self.mouseScaleY = (self.HEIGHT / self.dheight )
	print("Cairo MouseScale W/H:", self.mouseScaleX, self.mouseScaleY)

    self.RenderFPS = self.InternalRenderFPS
end

------------------------------------------------------------------------------------------------------------

function cairo_ui:InitGui(dw, dh)

	print(dw, dh)
	gui.new_texture("dynamic_tx", self.V_WIDTH, self.V_HEIGHT, "rgba", string.rep(string.char(0xff), self.V_WIDTH * self.V_HEIGHT * 4))	
	-- Create a box node and apply the texture to it.
	local n = gui.new_box_node(vmath.vector3(dw/2, dh/2, 0), vmath.vector3(self.WIDTH, self.HEIGHT, 0))
	gui.set_texture(n, "dynamic_tx")
end

------------------------------------------------------------------------------------------------------------
-- Closedown Cairo
function cairo_ui:Finish()

	for k,v in pairs(cairo_ui.imageList) do
		if(v.image) then
			if(v.data) then v.data = nil end 
			cr.cairo_surface_destroy ( v.image ) 
		end
	end

-- *************************************************************************
--- TODO: Figure just what the hell to do about startup/shutdown of cairo.
--		  Probably should run only one instance - will look into this.         
--        This will minimise mem foot print which is too big atm.
--	      Probably make cairo_ui singleton - self aware too (cant create more
--			than one of itself). And always returns that instance.
-- *************************************************************************
--   cr.cairo_destroy( self.ctx );
--   cr.cairo_surface_destroy( self.sf );
--   
--   self.ctx 	= nil
--   self.sf 		= nil
end

------------------------------------------------------------------------------------------------------------

function cairo_ui:RenderSurface(svgdata)

	-- Root level should have svg label and xargs containing surface information
	local label = svgdata["label"]
	if(label == "svg") then
		cr.cairo_stroke (self.ctx)	
		
		-- Get the surface sizes, and so forth
		local xargs = svgdata["xarg"]
		local width = tonumber(xargs["width"])
		local height = tonumber(xargs["height"])
		local xmlns = xargs["xmlns"]

		for k,v in pairs(svgdata) do
			cairo_ui:RenderSvg(v)
		end
	end
end

------------------------------------------------------------------------------------------------------------
-- Start the Rendering of UI to the Cairo surface/context

function cairo_ui:Begin(dt)

	-- Update the tweening 
	local timeDiff = dt
	tween.update(timeDiff)

	cr.cairo_save (self.ctx)
	cr.cairo_set_source_rgba (self.ctx, 0, 0, 0, 0)
	cr.cairo_set_operator (self.ctx, cr.CAIRO_OPERATOR_SOURCE)
	cr.cairo_paint (self.ctx)
	cr.cairo_restore (self.ctx)

	-- Object list every frame
	self.objectList 	= {}
	self.objectCount 	= 1
	self.image_counter = 1

    -- Render any svgs
    for k,v in pairs(self.svgs) do
        cr.cairo_save (self.ctx)
        if v.pos then cr.cairo_translate(self.ctx, v.pos.x, v.pos.y) end
        self:RenderSvg(v)
        cr.cairo_restore (self.ctx)
    end
end

------------------------------------------------------------------------------------------------------------

function cairo_ui:CheckListScroll(buttons, mx, my, obj, state)
			
	if obj == nil then return end
				
	-- Check the list scroll area and if in the region
	if(InRegion( obj, mx, my) == true) then	

		-- Holding mouse down on the slider.. move the slider.
        local sdiff = 0
		if buttons[1] == true then
			sdiff = my - self.oldmy
        end

		if buttons[10] then
        if buttons[10] ~= 0.0 then sdiff = buttons[10] * 0.25 end
		end 
	
        if sdiff ~= 0 then
            state.scroll = state.scroll + sdiff
        end
		
		-- Mouse released on list slider.. then stop sliding
		if buttons[1] == false and self.lastMouseButton[1] == true then
		
		end
	end
end

------------------------------------------------------------------------------------------------------------
-- Upon completion of rendering he Cairo surface pass it to the OpenGL texture

function cairo_ui:Update(mxi, myi, buttons, dt)

	-- Scale the mouse position because of the Interface/Window scaling
	local mx = mxi * self.mouseScaleX
	local my = myi * self.mouseScaleY

	-- TODO:
	-------------------------------------------------------------------------------------------------------
	-- #######   CLEAN THIS SHIT UP DAVE!!!    ########
	
	-- TODO:     This Update function will soo be changed.. lots to do .. lots to cleanup.
	-------------------------------------------------------------------------------------------------------
	-- Iterate Objects and detect button hits and similar
	for k,v in ipairs(self.objectList) do
		
		if v ~= nil then
			local handler = self.widget_handlers[v.otype]
			if handler ~= nil then handler(self, v, mx, my, buttons) end
		end
	end
	
	self.oldmx = mx
	self.oldmy = my
	
	--  ***   TODO:  Need a Mouse Handler  *** --
	-- Bit of a hack.. 	
	self.lastMouseButton[1] = buttons[1]
	self.lastMouseButton[2] = buttons[2]
	self.lastMouseButton[3] = buttons[3]	
end

------------------------------------------------------------------------------------------------------------
-- Render FPS system

function cairo_ui:InternalRenderFPS()

    -- Enable frameMs rendering for profiling.
    ttime = os.clock()
	-- collect 20 frames to measure
	self.frame = self.frame + 1
	if self.frame >= 20 then 
		self.fps = 20.0 / (ttime - self.lastclock)
		self.ms = string.format("FPS: %02.2f", self.fps)
		self.lastclock = ttime
		self.frame = 0
	end 
    self:RenderText(self.ms, 90, 18, 12)
end

------------------------------------------------------------------------------------------------------------
-- Upon completion of rendering he Cairo surface pass it to the OpenGL texture

function cairo_ui:Render()

    if self.RenderFPS then self:RenderFPS() end

-- 	-- *** TODO:  Probably need to make this a little more freindly if we need multiple surfaces/layers  **** --
-- 	byt3dRender:ChangeShader(self.uiShader)
-- 	gl.glDisable ( gl.GL_DEPTH_TEST )
-- 	gl.glBlendFunc ( gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA)
-- 	
-- -- print("Cairo_Shader Set", gl.glGetError())
-- 	gl.glUniform2f(self.loc_res, self.WIDTH, self.HEIGHT )
-- 	gl.glUniform1f(self.loc_time, os.clock())
-- 
-- 	gl.glActiveTexture(gl.GL_TEXTURE0)
-- 	gl.glBindTexture(gl.GL_TEXTURE_2D, self.tex.textureId)
-- 	gl.glUniform1i(self.uiShader.samplerTex[0], 0)
-- 	gl.glTexImage2D(gl.GL_TEXTURE_2D, 0, gl.GL_RGBA, self.V_WIDTH, self.V_HEIGHT, 0, gl.GL_RGBA, gl.GL_UNSIGNED_BYTE, self.data )
-- 
-- 	byt3dRender:RenderTexRect(self.mesh, -1, 1, 2, -2)
-- 
-- 	for y=0, self.V_HEIGHT-1 do
-- 		for x=0,self.V_WIDTH-1 do
-- 			local indexd = y * self.V_WIDTH * 4 + x * 4 + 1
-- 			local indexs = (self.V_HEIGHT - y - 1) * self.V_WIDTH * 4 + x * 4 + 1
-- 			self.stream[indexd + 0] = self.data[indexs + 0]
-- 			self.stream[indexd + 1] = self.data[indexs + 1]
-- 			self.stream[indexd + 2] = self.data[indexs + 2]
-- 			self.stream[indexd + 3] = self.data[indexs + 3]
-- 		end
-- 	end
-- 
-- 	resource.set_texture(self.dpath, self.textureheader, self.tex)		
-- 
end 

function cairo_ui:RenderGui()

	gui.set_texture_data("dynamic_tx", self.V_WIDTH, self.V_HEIGHT, "rgba", ffi.string(self.data, self.V_WIDTH * self.V_HEIGHT * 4))	
end

------------------------------------------------------------------------------------------------------------
-- Render a user interface 'box'

function cairo_ui:RenderBox(x, y, width, height, corner)
	-- a custom shape that could be wrapped in a function --
	local aspect        = 1.0     			-- aspect ratio --
	
	if corner == nil then corner = self.style.corner_size end
	local corner_radius = corner  	-- and corner curvature radius --
	
	local radius = corner_radius / aspect;
	local degrees = 3.14129 / 180.0;
	
	local colorA = self.style.button_color	
	local colorB = self.style.button_border_color	
	local border = self.style.border_width

    cr.cairo_save (self.ctx)

	cr.cairo_set_source_rgba( self.ctx, colorA.r, colorA.g, colorA.b, colorA.a)
	cr.cairo_new_path( self.ctx )
	cr.cairo_arc( self.ctx,x + width - radius, y + radius, radius, -90 * degrees, 0 * degrees)
	cr.cairo_arc( self.ctx, x + width - radius, y + height - radius, radius, 0 * degrees, 90 * degrees)
	cr.cairo_arc( self.ctx,x + radius, y + height - radius, radius, 90 * degrees, 180 * degrees)
	cr.cairo_arc( self.ctx,x + radius, y + radius, radius, 180 * degrees, 270 * degrees)
	cr.cairo_close_path( self.ctx )

	cr.cairo_fill_preserve( self.ctx )

	cr.cairo_set_source_rgba( self.ctx,  colorB.r, colorB.g, colorB.b, colorB.a )
	cr.cairo_set_line_width( self.ctx, border)
	cr.cairo_stroke( self.ctx )

    cr.cairo_restore (self.ctx)
end

------------------------------------------------------------------------------------------------------------

return cairo_ui

------------------------------------------------------------------------------------------------------------
