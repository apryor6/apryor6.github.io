
template_file = 'gallery-template.md'
output_filename = 'gallery.md'
base_html_filename = 'visualizations/bokeh/figures/'
template_fillers = {
    'bokeh_glyphs_annular_wedge':'glyph-annular-wedge.html',
    'bokeh_glyphs_annulus':'glyph-annulus.html',
    'bokeh_glyphs_arc':'glyph-arc.html',
    'bokeh_glyphs_asterisk':'glyph-asterisk.html',
	'bokeh_glyphs_circle':'glyph-circle.html',
    'bokeh_glyphs_circle_cross':'glyph-circle-cross.html',
    'bokeh_glyphs_circle_x':'glyph-circle-x.html',
    'bokeh_glyphs_cross':'glyph-cross.html',
    'bokeh_glyphs_diamond':'glyph-diamond.html',
    'bokeh_glyphs_diamond_cross':'glyph-diamond-cross.html',
    'bokeh_glyphs_ellipse':'glyph-ellipse.html',
    'bokeh_glyphs_hbar':'glyph-hbar.html',
    'bokeh_glyphs_image':'glyph-image.html',
	'bokeh_glyphs_square':'glyph-square.html',
	'bokeh_glyphs_triangle':'glyph-triangle.html',
	'bokeh_glyphs_vbar':'glyph-vbar.html',

	
	
}
template_fillers = {k:base_html_filename+v for (k, v) in template_fillers.items()}

format_dict = {}
for k,v in template_fillers.items():
    with open(v, 'r') as fid:
    	format_dict.update({k:fid.read()})

with open(template_file,'r') as fi, open(output_filename, 'w') as fo:
	fo.write(fi.read().format(**format_dict).replace('<!DOCTYPE html>',''))