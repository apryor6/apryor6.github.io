
# Bokeh Patch Glyph


```python
from bokeh.plotting import figure, output_file, show
from bokeh.models import Range1d
from bokeh.io import export_png

fill_colors = ['#e31a1c','#b2df8a','#a6cee3','#cab2d6']
line_colors = ['#e31a1c','#33a02c','#1f78b4','#6a3d9a']
output_file("../../figures/patch.html")

p = figure(plot_width=400, plot_height=400)
p.patch(x=[0, 0.5, 0, 0.5],y=[0, 0.5, 0.5,  0], fill_alpha=1,fill_color=fill_colors[0],
         line_alpha=1, line_color=line_colors[0], line_dash='solid', line_width=5)
p.patch(x=[0.75 + i for i in [0, 0, 0.5, 0.5]],y=[0, 0.5, 0.5,  0], fill_alpha=1,fill_color=fill_colors[1],
         line_alpha=1, line_color=line_colors[1], line_dash='dotdash', line_width=5)
p.patch(x=[0.75 + i for i in [0, 0, 0.5, 0.5]],y=[0.75 + i for i in [0.1, 0.29, 0.33,  .69]], fill_alpha=1,fill_color=fill_colors[2],
         line_alpha=1, line_color=line_colors[2], line_dash='dashed', line_width=5)
p.patch(x=[0, 0, 0.4, 0.34],y=[0.75 + i for i in [0.6, 0.29, 0.33,  .69]], fill_alpha=1,fill_color=fill_colors[3],
         line_alpha=1, line_color=line_colors[3], line_dash='dotted', line_width=5)
p.x_range = Range1d(-0.5,1.5, bounds=(-1,2))
p.y_range = Range1d(-0.5,1.5, bounds=(-1,2))
show(p)
export_png(p, filename="../../figures/patch.png");
```
