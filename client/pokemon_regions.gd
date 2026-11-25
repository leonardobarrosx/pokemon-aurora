extends RefCounted

# Explicit source palettes, per species AND pose. Unmapped pixels remain original.
const PALETTES={
 "2":{"front":{"skin":"5acebd 219484 84e6d6","markings":"104a3a","accessory":"317b52 7bd673 63ad5a d6425a ff7b7b ffada5","eye":"7b3129"},"follower":{"skin":"48a898 68d0c0 408078","accessory":"c85878 60a810 305818 88e020 f080a0","eye":"682028"}},
 "5":{"front":{"skin":"ce3a3a ff524a 942110 ff846b","markings":"e6cead b58c5a cead7b","flame":"ff4200 ffde29 ffa500","eye":"005aff"},"follower":{"skin":"f86858 b84038 601820","flame":"c81028","markings":"d8a830 f0d070","eye":"286880"}},
 "8":{"front":{"skin":"8cadf7 637bc5 adc5ff 29426b","accessory":"946363 6b4a19 8c5a21","markings":"dec58c ad8c63","effects":"d6eff7 bdc5e6"},"follower":{"skin":"7098e0 4078d8 405098","accessory":"a05818","markings":"b88818 f0d070","eye":"a00830"}},
 "26":{"front":{"fur":"f7ad29 de7b31 bd5a31","effects":"ffbd00 ffde5a","markings":"8c6310 734231 944242","accessory":"ffefd6 e7bd84","mouth":"bd1808"},"follower":{"fur":"f89000 d07820 f8c040","markings":"704828 885818 482818","effects":"d0b018 f8e008","accessory":"c0b080 786848 f8e8d0"}},
 "134":{"front":{"fur":"5ac5e6 429cbd 84deff 107394 104a63","accessory":"ffe6a5 bdad5a 6b6321","eye":"521073","mouth":"7b0829 d65273"},"follower":{"fur":"58b0e0 4888b0 80c8e8 306888","markings":"209088 107078","accessory":"d0d0d0 a0a0a0 e0c868 b09838"}},
 "135":{"front":{"fur":"ffde52 cead4a 846b29 ffff8c ad8c3a","accessory":"c5c5c5 525252","eye":"4a087b"},"follower":{"fur":"f8f850 f8c818 e8a020 a86820","accessory":"a8a8c0 d0e0e8"}},
 "136":{"front":{"fur":"f7734a d64252 732119 a54252","accessory":"ffefa5 c5a56b debd8c 735a42","eye":"21216b"},"follower":{"fur":"f88048 d85820 984028 c04020","accessory":"e8d898 d8a848 987830"}},

 "1":{
  "front":{"skin":"3a9494 63d6b5 84efc5","markings":"317373","accessory":"73ad31 a5d642 bdff73 526329","eye":"ad0031 ef213a","mouth":"ff6b63"},
  "follower":{"skin":"74d3ae 3a9494","accessory":"73ad31 a7e165 526329","eye":"681018 b83018"}},
 "4":{
  "front":{"skin":"ff9442 de523a 8c2900","markings":"ffd67b e6ad5a ffc563","flame":"e63a00 ffd608 f7a500","eye":"083a8c 198cb5 31adef"},
  "follower":{"skin":"f88838 b85820","markings":"f0d070 d8a830","flame":"e02828","eye":"284858"}},
 "7":{
  "front":{"skin":"5a9ca5 8cc5ce 297384 b5e6ef","accessory":"ce7b29 842900 bd6b00 632900 d69452","markings":"e6ad5a ffe69c ffd66b"},
  "follower":{"skin":"58b8f0 3888b8","accessory":"c87818","markings":"d8a830 f0d070","eye":"a00830"}},
 "25":{
  "front":{"fur":"f7e652 f7bd21 de9400 fff7a5","markings":"9c5200 633108","effects":"c52119 e65a42"},
  "follower":{"fur":"f8d050 c8a040","markings":"705038 987038","effects":"c85838 903818"}},
 "133":{
  "front":{"fur":"a5634a d69c4a 734a4a","accessory":"e6c594 ffe6ad bd9c7b"},
  "follower":{"fur":"c09050 a88040 806030","accessory":"b8a060 e0d0a8 786040"}},
 "94":{
  "front":{"skin":"9473b5 5a4a9c b58cbd 4a294a 7b63a5","eye":"ff5a5a ff9494"},
  "follower":{"skin":"685080 9078a0 503868 282838","eye":"d86060 f8a8a0"}},
 "197":{
  "front":{"fur":"424252 29314a 63637b","markings":"b59429 efd652 525200","eye":"6b2110 ad424a"},
  "follower":{"fur":"687078 182838 404850 283840","markings":"b08010 f8d858 e0b028 805808","eye":"700808 d01818"}}
}
const LABELS={"skin":"Pele","fur":"Pelagem","flame":"Chama","effects":"Efeitos / bochechas","eye":"Olhos","mouth":"Boca / língua","nose":"Nariz","markings":"Desenhos naturais","accessory":"Bulbo / casco / gola"}

static func colors(look:Dictionary)->Dictionary:
	var result={}
	for key in LABELS:
		var legacy="body" if key in ["skin","fur"] else (key if key in ["eye","mouth"] else "detail")
		result[key]=look.get("regions",{}).get(key,"original" if key=="nose" else look.get(legacy,"original"))
	return result

static func apply(image:Image,sid:String,mode:String,frame:int,look:Dictionary)->Image:
	var palette:Dictionary=PALETTES.get(sid,{}).get("front" if mode=="back" else mode,{})
	if palette.is_empty():return image # Unknown anatomy is never guessed from hue.
	var mapping={}
	for region in palette:
		for hex in palette[region].split(" "):mapping[hex]=region
	var chosen=colors(look)
	for fy in range(0,image.get_height(),frame):
		for fx in range(0,image.get_width(),frame):
			var bounds=image.get_region(Rect2i(fx,fy,frame,frame)).get_used_rect()
			var seed_value=int(look.get("seed",0))
			var placement=int(look.get("mark_place",0))%5
			var anchors=[Vector2(.32,.56),Vector2(.68,.56),Vector2(.42,.72),Vector2(.6,.78),Vector2(.5,.46)]
			var anchor=anchors[placement]
			if mode=="follower" and fy/frame==2:anchor.x=1-anchor.x
			var point=Vector2(bounds.position)+Vector2(bounds.size)*anchor
			var marked=0
			for y in range(frame):
				for x in range(frame):
					var c=image.get_pixel(fx+x,fy+y)
					if c.a<.5:continue
					var region=str(mapping.get(c.to_html(false),""))
					if region=="":continue
					var target=str(chosen[region])
					# At most one tiny birthmark, or a restrained 2-pixel pattern accent.
					if region in ["skin","fur"] and marked<4 and Vector2(x,y).distance_to(point)<1.5:
						if look.get("mark","")=="Sinal":target=look.get("mark_color","original");marked+=1
						elif look.get("pattern","Liso")!="Liso" and posmod(seed_value+x+y,3)==0:target=look.get("detail","original");marked+=1
					if target=="original":continue
					var pigment=Color(target)
					# Preserve luminosity: highlights stay part of the same material.
					var out=Color.from_hsv(pigment.h,pigment.s*clampf(c.s+.25,.3,1),c.v*lerpf(.65,1.15,pigment.v))
					out.a=c.a;image.set_pixel(fx+x,fy+y,out)
	return image
