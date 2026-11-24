# Exports the owner's existing Gen 4 v2 catalog without modifying the source.
require 'json'
require 'zlib'
require 'fileutils'
require 'digest'
source, destination = ARGV
abort 'usage: ruby export_indigo_character.rb char_g4.dat destination' unless destination
data = Marshal.load(File.binread(source))
abort 'expected catalog v2' unless data[:v] == 2
SIZES = {walk:[256,256],run:[256,256],bike:[256,256],surf:[256,256],fish:[512,512],fishsurf:[256,256],front:[160,160],back:[800,220],layer:[256,256]}
def chunk(type, bytes)
  [bytes.bytesize].pack('N') + type + bytes + [Zlib.crc32(type + bytes)].pack('N')
end
def png(path,w,h,rgba)
  scan = (0...h).map { |y| "\0".b + rgba.byteslice(y*w*4,w*4) }.join
  File.binwrite(path,"\x89PNG\r\n\x1a\n".b + chunk('IHDR',[w,h,8,6,0,0,0].pack('NNC5')) + chunk('IDAT',Zlib::Deflate.deflate(scan)) + chunk('IEND',''.b))
end
FileUtils.mkdir_p(destination)
manifest={version:2,source:'Pokémon Añil V4.13/Data/char_g4.dat',sha256:Digest::SHA256.file(source).hexdigest,credits:'Coffee Cup / Poltergeist; adaptação do criador Pokémon Indigo',order:data[:order],parts:{}}
data[:parts].each do |key,p|
  safe=key.gsub('|','_')
  entry={name:p[:name],palette:p[:pal],groups:p[:grp],refs:p[:refs],defaults:p[:defaults],modes:{}}
  p[:modes].each do |mode,compressed|
    size=SIZES[mode];next unless size
    w,h=size
    if mode==:layer && key=='rod';w=512;h=512;end
    raw=Zlib::Inflate.inflate(compressed)
    rgba="\0".b*(w*h*4)
    raw.bytes.each_slice(3) do |lo,hi,index|
      offset=lo|(hi<<8);x=(offset%(w/2))*2;y=(offset/(w/2))*2
      next if y+1>=h
      rgb=p[:pal][index-1];next unless rgb
      px=[*rgb,255].pack('C4')*2
      rgba[(y*w+x)*4,8]=px;rgba[((y+1)*w+x)*4,8]=px
    end
    filename="#{safe}_#{mode}.png"
    png(File.join(destination,filename),w,h,rgba)
    entry[:modes][mode]=filename
  end
  manifest[:parts][key]=entry
end
File.write(File.join(destination,'catalog.json'),JSON.generate(manifest))
puts "Exported #{manifest[:parts].size} original character parts, eight poses where available."
