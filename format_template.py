
template_file = 'gallery-template.md'
output_filename = 'gallery.md'
base_html_filename = 'visualizations/bokeh/figures/'
template_fillers = {
	'bokeh_glyphs_circle':'glyph-circle.html',
	'bokeh_glyphs_square':'glyph-square.html',
	'bokeh_glyphs_triangle':'glyph-triangle.html'
}
template_fillers = {k:base_html_filename+v for (k, v) in template_fillers.items()}

format_dict = {}
for k,v in template_fillers.items():
    with open(v, 'r') as fid:
    	format_dict.update({k:fid.read()})

with open(template_file,'r') as fi, open(output_filename, 'w') as fo:
	fo.write(fi.read().format(**format_dict).replace('<!DOCTYPE html>',''))