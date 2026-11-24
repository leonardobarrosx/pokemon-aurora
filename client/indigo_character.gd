extends RefCounted

var catalog:Dictionary={}
var cache:Dictionary={}
const ORDER=["base","bottom","top","bag","hair","hat","acc"]
const REGIONS={"base":{1:"skin"},"hair":{1:"hair"},"top":{1:"top",2:"top2"},"bottom":{1:"bottom",2:"bottom2",3:"shoes"},"hat":{1:"hat",2:"hat2"},"bag":{1:"bag",2:"bag2"},"acc":{1:"acc",2:"acc2"}}

func _init():
	catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/indigo/character/catalog.json"))

func compose(look:Dictionary,colors:Dictionary,mode:String="walk")->Texture2D:
	var cache_key=mode+JSON.stringify(look)+JSON.stringify(colors)
	if cache.has(cache_key):return cache[cache_key]
	var size=Vector2i(256,256)
	if mode=="front":size=Vector2i(160,160)
	if mode=="back":size=Vector2i(800,220)
	if mode=="fish":size=Vector2i(512,512)
	var output=Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
	var gender=str(look.get("gender","m"))
	if mode in ["surf","fishsurf"] and catalog.parts.has("mount"):
		var mount=catalog.parts.mount
		if mount.modes.has("layer"):
			var mount_image:Image=load("res://assets/indigo/character/"+mount.modes.layer).get_image();mount_image.convert(Image.FORMAT_RGBA8);output.blend_rect(mount_image,Rect2i(Vector2i.ZERO,size),Vector2i.ZERO)
	for slot in ORDER:
		var choice=str(look.get(slot,{"hair":"boy2","top":"jacket","bottom":"jeans"}.get(slot,"")))
		if choice=="" and slot!="base":continue
		var key="base|"+gender if slot=="base" else slot+"|"+choice+"|"+gender
		if not catalog.parts.has(key):key=slot+"|"+choice+"|x"
		if not catalog.parts.has(key):continue
		var part:Dictionary=catalog.parts[key]
		if not part.modes.has(mode):continue
		var image:Image=load("res://assets/indigo/character/"+part.modes[mode]).get_image()
		image.convert(Image.FORMAT_RGBA8)
		var swaps:Dictionary={}
		for i in part.palette.size():
			var group=int(part.groups[i]);var region=REGIONS[slot].get(group,"")
			if not colors.has(region):continue
			var p=part.palette[i];var src=Color8(p[0],p[1],p[2]);var target=Color(colors[region]);var reference=part.defaults.get(str(group),[128,128,128]);var ref=Color8(reference[0],reference[1],reference[2]);var dest=Color.from_hsv(target.h,clampf(src.s*target.s/maxf(ref.s,.05),0,1),clampf(src.v*target.v/maxf(ref.v,.05),0,1));swaps[src.to_rgba32()]=dest
		if not swaps.is_empty():
			for y in range(image.get_height()):
				for x in range(image.get_width()):
					var src=image.get_pixel(x,y)
					if src.a>.5 and swaps.has(src.to_rgba32()):image.set_pixel(x,y,swaps[src.to_rgba32()])
		output.blend_rect(image,Rect2i(Vector2i.ZERO,size),Vector2i.ZERO)
	if mode in ["fish","fishsurf"]:
		var rod=catalog.parts.get("rod" if mode=="fish" else "surfrod",{})
		if rod.get("modes",{}).has("layer"):
			var rod_image:Image=load("res://assets/indigo/character/"+rod.modes.layer).get_image();rod_image.convert(Image.FORMAT_RGBA8);output.blend_rect(rod_image,Rect2i(Vector2i.ZERO,size),Vector2i.ZERO)
	var result=ImageTexture.create_from_image(output)
	if cache.size()>48:cache.clear()
	cache[cache_key]=result
	return result
