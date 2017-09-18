
template_file = 'gallery-template.md'
output_filename = 'gallery.md'
base_filename = 'http://alanpryorjr.com/visualizations/'
base_image_filename  = '../visualizations/'
key_base = "bokeh_glyphs_{}"
glyph_names = ['annular_wedge', 'annulus','arc','asterisk','circle',
'circle_cross','circle_x','cross','diamond','diamond_cross','ellipse',
'hbar','image','image_rgba', 'image_url', 'square','triangle','vbar']

glyph_format_dict = dict(glyph_base_code_filename=base_filename+'bokeh/glyphs/',
	                     glyph_base_html_filename=base_filename+'bokeh/figures/',
	                     glyph_base_image_filename=base_image_filename+'bokeh/figures/')

filler_template = """
<a name="bokeh-glyphs-{glyph_name}"></a>
#### {Glyph_name} ([Interactive]({glyph_base_html_filename}{glyph_name})) [(code)]({glyph_base_code_filename}{glyph_name}/{glyph_name})
![{Glyph_name}]({glyph_img_file})
"""
format_dict = {}
for glyph_name in glyph_names:
	key = key_base.format(glyph_name)
	glyph_format_dict['Glyph_name'] = ' '.join(g.capitalize() for g in glyph_name.split('_')) 
	glyph_format_dict['glyph_name'] = glyph_name
	glyph_format_dict['glyph_img_file'] = glyph_format_dict['glyph_base_image_filename'] + glyph_name + '.png'
	format_dict[key] = filler_template.format(**glyph_format_dict)

with open(template_file,'r') as fi, open(output_filename, 'w') as fo:
	fo.write(fi.read().format(**format_dict).replace('<!DOCTYPE html>',''))